package main

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/turbinelabs/cli"
	"github.com/turbinelabs/cli/command"
	tbnflag "github.com/turbinelabs/nonstdlib/flag"
	"github.com/turbinelabs/nonstdlib/log/console"
	tbnstrings "github.com/turbinelabs/nonstdlib/strings"
)

const (
	maxRPS     = 100
	minRPS     = 1
	defaultRPS = 20
)

// TbnPublicVersion is the current version of all Turbine Labs open-source
// software and artifacts.
const TbnPublicVersion = "0.18.2"

type driver struct {
	errorRates map[string]float64
	latencies  map[string]time.Duration
	host       string
	path       string
	rps        int
}

func (d driver) drive() error {
	// the golang http lib doesn't strip port 80 from HTTP requests like it should
	host := strings.TrimRight(d.host, ":80")
	url := fmt.Sprintf("http://%s/%s", host, d.path)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return err
	}

	console.Info().Printf("Sending %d RPS to %s", d.rps, url)

	if len(d.errorRates) > 0 {
		console.Info().Printf("Error-rate targets:")
	}

	for k, v := range d.errorRates {
		headerK := fmt.Sprintf("x-%s-error", k)
		headerV := fmt.Sprintf("%f", v)
		req.Header.Add(headerK, headerV)
		console.Info().Printf("  %s: %0.2f", k, v)
	}

	if len(d.latencies) > 0 {
		console.Info().Printf("Latency targets:")
	}

	var maxLatency time.Duration
	for k, v := range d.latencies {
		if v > maxLatency {
			maxLatency = v
		}
		headerK := fmt.Sprintf("x-%s-delay", k)
		headerV := strconv.Itoa(int(v / time.Millisecond))
		req.Header.Add(headerK, headerV)
		console.Info().Printf("  %s: %sms", k, headerV)
	}

	timeout := time.Second
	if maxLatency*10 > timeout {
		timeout = maxLatency * 10
	}
	console.Info().Printf("Timeout: %dms", timeout/time.Millisecond)

	client := &http.Client{
		Timeout: timeout,
	}

	rate := time.Second / time.Duration(d.rps)
	throttle := time.Tick(rate)

	count := 0
	for {
		<-throttle // rate limit our Service.Method RPCs
		go func() {
			count++
			if count%(d.rps*10) == 0 {
				console.Info().Printf("%d requests sent", count)
			}
			res, err := client.Do(req)
			if err != nil {
				console.Error().Println(err)
			}
			if res != nil && res.Body != nil {
				res.Body.Close()
			}
		}()
	}
}

func cmd() *command.Cmd {
	r := &runner{
		errorRatesFlag: tbnflag.NewStrings(),
		latenciesFlag:  tbnflag.NewStrings(),
	}

	c := &command.Cmd{
		Name:        "all-in-one-driver",
		Summary:     "drive traffic to an all-in-one api server",
		Usage:       "[OPTIONS]",
		Description: "drive traffic to an all-in-one api server",
		Runner:      r,
	}

	fs := tbnflag.Wrap(&c.Flags)

	fs.Var(
		&r.errorRatesFlag,
		"error-rates",
		"Floating-point error rates by color; formatted as `<color>:<rate>,...` (e.g.: `blue:0.01`). Multiple clients may be specified separated by commas or `error-rates` may be passed multiple times.",
	)

	fs.Var(
		&r.latenciesFlag,
		"latencies",
		"Latency durations by color; formatted as `<color>:<duration>,...` (e.g.: `blue:24ms`). Multiple clients may be specified separated by commas or `latencies` may be passed multiple times.",
	)

	fs.IntVar(
		&r.rps,
		"rps",
		defaultRPS,
		fmt.Sprintf(
			"Target requests per second, between %d and %d, inclusive. Best effort.",
			minRPS,
			maxRPS,
		),
	)

	fs.HostPortVar(
		&r.host,
		"host",
		tbnflag.NewHostPort("127.0.0.1:80"),
		"the addr on which to contact the all-in-one server",
	)

	fs.StringVar(
		&r.path,
		"path",
		"api",
		"The path to the query on the all-in-one server",
	)

	console.Init(tbnflag.Wrap(&c.Flags))

	return c
}

type runner struct {
	errorRatesFlag tbnflag.Strings
	latenciesFlag  tbnflag.Strings
	host           tbnflag.HostPort
	path           string
	rps            int
}

func extractLatencies(f tbnflag.Strings) (map[string]time.Duration, error) {
	res := make(map[string]time.Duration, len(f.Strings))
	for _, s := range f.Strings {
		k, vs := tbnstrings.SplitFirstColon(s)
		vd, err := time.ParseDuration(vs)
		if err != nil {
			return nil, fmt.Errorf("bad duration (%s:%s): %s", k, vs, err)
		}
		if vd <= 0 {
			return nil, fmt.Errorf("duration (%s:%s) must be > 0", k, vs)
		}
		res[k] = vd
	}
	return res, nil
}

func extractErrorRates(f tbnflag.Strings) (map[string]float64, error) {
	res := make(map[string]float64, len(f.Strings))
	for _, s := range f.Strings {
		k, vs := tbnstrings.SplitFirstColon(s)
		vf, err := strconv.ParseFloat(vs, 64)
		if err != nil {
			return nil, fmt.Errorf("bad error rate (%s:%s): %s", k, vs, err)
		}
		if vf < 0 {
			return nil, fmt.Errorf("error rate (%s:%s) must be >= 0", k, vs)
		}
		res[k] = vf
	}
	return res, nil
}

func (r *runner) Run(cmd *command.Cmd, args []string) command.CmdErr {
	latencies, err := extractLatencies(r.latenciesFlag)
	if err != nil {
		return cmd.BadInput(err)
	}

	errorRates, err := extractErrorRates(r.errorRatesFlag)
	if err != nil {
		return cmd.BadInput(err)
	}

	if r.rps < minRPS {
		return cmd.BadInputf("bad value for --rps: %d: must be >= %d", r.rps, minRPS)
	}

	if r.rps > maxRPS {
		return cmd.BadInputf("bad value for --rps: %d: must be <= %d", r.rps, maxRPS)
	}

	d := driver{errorRates, latencies, r.host.Addr(), r.path, r.rps}

	if err := d.drive(); err != nil {
		return cmd.Error(err)
	}

	return command.NoError()
}

func mkCLI() cli.CLI {
	return cli.New(TbnPublicVersion, cmd())
}

func main() {
	mkCLI().Main()
}
