// just pull all query params out so we can use them as headers
var urlParams={};
window.location.search.replace(/[?&]+([^=&]+)=([^&]*)/gi, function(str,key,value){
  urlParams[key] = value;
});

var urlFromEnv = '{{envOrDefault "TBN_URL" ""}}';

function cellId(path, i, j) {
  return path + "-" + i + "-" + j;
}

function urlFor(path, i, j) {
  if (urlFromEnv) {
    return urlFromEnv + "/api/" + path;
  }
  return location.protocol + '//' + location.hostname + (location.port ? ':' +location.port: '') + "/api/" + path;
}

var running = true;

// set up an N x M table, with each cell backed by an ajax worker that
// periodically repaints it
function createTable(rows, cols, path) {
  var tbl = $("<table style='background-color: #222222;'></table>");
  tbl.data("worker", {path: path, rows: rows, cols: cols});
  $("#container").append("<h1 style='color: #D8D8D8'>/" + path + "</h1>");
  $("#container").append(tbl);

  for (var i = 0; i < rows; i++) {
    var row = $("<tr></tr>");
    tbl.append(row);
    for (var j = 0; j < cols; j++) {
      // grossssss
      var cell = $("<td><div style='width: 22px; height: 22px; background-color=#CCCCCC'><div style='width: 20px; height: 20px;' id='" + cellId(path, i, j) + "'/><div></td>");
      row.append(cell);
      countdown(i, j, path);
    }
  }
  // drop in a spacer for the next table
  $("#container").append("<div style='height:25px;'></div>");
}

// Fades the given cell to 15% opacity with a random delay, and at the
// end makes an ajax call. On success drawCell is invoked to render
// the cell with the result (a color). On failure, drawCell is invoked
// to render the cell red.
function countdown(i, j, path) {
  var fetch = function() {
    if (!running) {
      return;
    }

    // convert cookies to headers because jquery doesn't like you setting
    // cookies on XHR requests
    $.each(document.cookie.split(/; */), function()  {
      var splitCookie = this.split('=');
      urlParams['X-' + splitCookie[0]] = splitCookie[1];
    });

    var url = urlFor(path, i, j);
    $.ajax({
      url: url,
      timeout: 5000,
      headers: urlParams,
      success: function(data) {
        drawCell(i, j, path, data);
      },
      error: function(request, status, err) {
        console.log("demo ajax call failure: " + err);
        drawCell(i, j, path, "#FF0000");
      }
    });
  };

  // fade out, and on completion execute the ajax call
  var cell = $("#" + cellId(path, i, j));
  var delay = Math.random() * 1000;
  cell.fadeTo(delay, 0.15, fetch);
}

// Paints the cell the given color, fades to full opacity, and calls
// countdown.
function drawCell(i, j, path, color) {
  var cell = $("#" + cellId(path, i, j));
  cell.css("background-color", color);

  var nextCountdown = function() {
      countdown(i, j, path);
  };
  cell.fadeTo("slow", 1.0, nextCountdown);
}

function createControls() {
  $("#controls").append('<button id="play">Pause</button>');

  var width = $("#controls button").width();
  $("#controls button").width(width);

  $("#play").click(function() {
    running = !running;
    if (running) {
      $("#play").html("Pause");
      restart();
    } else {
      $("#play").html("Play");
    }
  });
}

function restart() {
  $("#container table").each(function(x, tbl) {
    var worker = $(tbl).data("worker");
    for (var i = 0; i < worker.rows; i++) {
      for (var j = 0; j < worker.cols; j++) {
        countdown(i, j, worker.path);
      }
    }
  });
}

// set up the tables
$(document).ready(function() {
  createControls();
  createTable(2, 10, "blocks");
  createTable(1, 10, "users");
  createTable(1, 10, "logs");
});
