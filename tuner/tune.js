$(document).ready(function() {
    overrides = {};
  
    function ind2name(ind) {
      ind = ind - 1;
      x = (ind % 9) + 1;
      y = Math.floor(ind / 9) + 1;
      return 'tiles/t' + x + '_' + y + '.png';
    }
    
    function applyOverrides() {
      var modifiedGraph = [];
      
      for (i = 0; i < graphData.length/4; i++) {
        offset = i*4;
        ind1 = graphData[offset];
        ind2 = graphData[offset + 1];
        var a = ind2name(ind1);
        var b = ind2name(ind2);
        var dx = graphData[offset + 2];
        var dy = graphData[offset + 3];
        
        override = overrides[ind1 + '_' + ind2];
        if (override) {
          dx = override[0];
          dy = override[1];
        }
        
        modifiedGraph.push(ind1, ind2, dx, dy);
      }

      return modifiedGraph;
    }
    
    function loadGraph() {
      var adjacency = {};
      var graphData = applyOverrides();
      for (i = 0; i < graphData.length/4; i++) {
        offset = i*4;
        ind1 = graphData[offset];
        ind2 = graphData[offset + 1];
        var a = ind2name(ind1);
        var b = ind2name(ind2);
        var dx = graphData[offset + 2];
        var dy = graphData[offset + 3];
        
        if (!adjacency[a]) {
          adjacency[a] = [];
        }

        if (!adjacency[b]) {
          adjacency[b] = [];
        }

        // forward edge
        adjacency[a].push({
          id: b,
          ind: ind2,
          dx: dx,
          dy: dy
        });
        
        // back edge
        adjacency[b].push({
          id: a,
          ind: ind1,
          dx: -dx,
          dy: -dy
        });
      }

      return adjacency;
    }
    
    function computeAbsoluteCoordinates(graph) {
      var coordinates = {};
      
      var boundingBox = {
        top: 0,
        left: 0,
        bottom: 0,
        right: 0
      }
      
      function dfs(v) {
        
        var parentTop = coordinates[v].top;
        var parentLeft = coordinates[v].left;
        var parentWidth = coordinates[v].width;
        var parentHeight = coordinates[v].height;

        boundingBox.top = Math.min(parentTop, boundingBox.top);
        boundingBox.left = Math.min(parentLeft, boundingBox.left);
        boundingBox.bottom = Math.max(parentTop + parentHeight, boundingBox.bottom);
        boundingBox.right = Math.max(parentLeft + parentWidth, boundingBox.right);


        $.each(graph[v], function(k, adj) {
          if (!coordinates[adj.id]) {
            var top = parentTop + adj.dy;
            var left = parentLeft + adj.dx;
            coordinates[adj.id] = {
              source: v,
              top: top,
              left: left,
              width: 150,
              height: 150,
              ind: adj.ind
            };
            dfs(adj.id);
          }
        });
      }

      var vInitial = Object.keys(graph).sort()[0];

      coordinates[vInitial] = {
        top: 0,
        left: 0,
        width: 150,
        height: 150,
        ind: 1
      };
      
      dfs(vInitial);
      
      return {
        coordinates: coordinates,
        boundingBox: boundingBox
      };
    }
    
    function isEditing() {
      return $('#tuner').hasClass('pair-editor');
    }

    function isDownloading() {
      return $('body').hasClass('download');
    }
    
    function move(key, fineGrain) {
      var movableTile = $('#composite>img.movable');
      var pos = movableTile.position();
      var top = pos.top;
      var left = pos.left;
      
      var increment;
      if (fineGrain) {
        increment = 0.1;
      } else {
        increment = 1;
      }
      
      switch (key) {
        case 37:
          left -= increment;
          break;
        case 38:
          top -= increment;
          break;
        case 39:
          left += increment;
          break;
        case 40:
          top += increment;
          break;
      }
      movableTile.css({top: top, left: left});
    }
    
    function initialize() {
      $('#tuner').removeClass('pair-editor');
      $('#composite img').removeClass('selected');
      graph = loadGraph();
      coordinates = computeAbsoluteCoordinates(graph);
      renderTiles(coordinates);
    }
    
    function accept() {
      if (!isEditing()) {
        return;
      }

      var selectedTiles = $('#composite>img.selected');
      firstTile = $(selectedTiles.get(0));
      secondTile = $(selectedTiles.get(1));
      ind1 = firstTile.data('ind');
      ind2 = secondTile.data('ind');
      pos1 = firstTile.position();
      pos2 = secondTile.position();

      var dx = pos2.left - pos1.left;
      var dy = pos2.top - pos1.top;
      
      if (ind1 > ind2) {
        dx = -dx;
        dy = -dy;
        var t = ind1;
        ind1 = ind2;
        ind2 = t;
      }
      overrides[ind1 + '_' + ind2] = [dx, dy];
      
      initialize();
    }
    
    function cancel() {
      if (!isEditing()) {
        return;
      }
      initialize();
    }
    
    function download() {
      if (isEditing())
      {
        cancel();
      }

      $('body').addClass('download');
      
      var fuser = document.getElementById("fuser");
      
      var canvas = document.getElementById("canvas");
      fuser.width = canvas.width;
      fuser.height = canvas.width;
      
      const ctx = fuser.getContext('2d');
      
      ctx.globalCompositeOperation = 'luminosity';
      
      $('#composite img').each(function(k, v) {
        var pos = $(v).position();
        ctx.drawImage(v, pos.left, pos.top);
      });
      
      var graphData = applyOverrides();
      $('#graph-data').val('var graphData = ' + JSON.stringify(graphData) + ';');
    }
    
    function continueEditing() {
      $('body').removeClass('download');
    }
    

    function renderTiles(coordinates) {
      $('#composite').empty();

      var canvas = document.getElementById("canvas");
      canvas.width = coordinates.boundingBox.right;
      canvas.height = coordinates.boundingBox.bottom;

      var ctx = canvas.getContext("2d");
      ctx.lineWidth = 3;
      ctx.strokeStyle = "#FF0000";
      
      c = coordinates.coordinates;
      $.each(c, function(k, v) {
        var tile = $('<img>',
        {
          src: k,
          css: {
            top: v.top,
            left: v.left
          }
        })
        .data('ind', v.ind)
        .click(function(event) {
          if (isEditing()) {
            return;
          }

          var tile = $(event.target);
          tile.toggleClass('selected');
          
          var selectedTiles = $('#composite>img.selected');
          
          if (selectedTiles.length == 2) {
            $('#composite > img').removeClass('movable');
            $('#tuner').addClass('pair-editor');
            
            firstTile = $(selectedTiles.get(0));
            secondTile = $(selectedTiles.get(1));
            ind1 = firstTile.data('ind');
            ind2 = secondTile.data('ind');
            
            if (ind1 < ind2) {
              secondTile.addClass('movable');
            } else {
              firstTile.addClass('movable');
            }
          }
        });

        $('#composite').append(tile);

        var sourceCoordinates = c[v.source];
        
        if (sourceCoordinates) {
          var offset = 75;
          ctx.moveTo(sourceCoordinates.left + offset, sourceCoordinates.top + offset);
          ctx.lineTo(v.left + offset, v.top + offset);
          ctx.stroke();
        }
      });
    }
    
    var arrowKeys = new Array(37,38,39,40, 13, 27);

    $(document).keydown(function(event) {
      if (!isEditing() || isDownloading()) {
        return;
      }
      
      var key = event.which;
      if($.inArray(key, arrowKeys) > -1) {
        
        if (key == 13) {
          accept();
        } else if (key == 27) {
          cancel();
        } else {
          move(key, event.ctrlKey);
        }
        
        event.preventDefault();
        return false;
      }
      return true;
    });
    
    $('#download').click(download);
    $('#continue').click(continueEditing);
    initialize();
});
