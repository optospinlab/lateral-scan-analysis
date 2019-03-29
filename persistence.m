classdef persistence
  properties
    outputDir;
    rawData;
    coordinates;
    adjacency;
  endproperties
  methods
    function obj = persistence(outputDir, rawData, coordinates, adjacency)
      obj.outputDir = outputDir;
      obj.rawData = rawData;
      obj.coordinates = coordinates;
      obj.adjacency = adjacency;
      mkdir(outputDir);
      mkdir(outputDir, 'tiles');
    endfunction

    function write(obj)
      obj.writeTiles();
      for i = 0:length(obj.rawData)
        obj.writeOrientation(i);
      end
      obj.writeComposite();
      obj.writeGraph();
    endfunction
  end
    
  methods (Hidden, Access = protected)
    function writeTiles(obj)
      nr = normalizer(obj.rawData);

      iMax = size(obj.rawData{1}, 1);
      jMax = size(obj.rawData{1}, 2);

      for i = 1:iMax
        for j = 1:jMax
          A = nr.normalize(obj.rawData{1}{i, j});
          B = nr.normalize(obj.rawData{2}{i, j});
          
          C = cat(3, B, A, zeros(size(A)));

          name = strcat('t', num2str(i), '_', num2str(j), '.png');
          outputFileName = fullfile(obj.outputDir, 'tiles', name);
          imwrite(C, outputFileName);
        end
      end
    endfunction
    
    function writeOrientation(obj, idx)
      maxRow = int32(obj.coordinates{end}(1) + 100);
      maxColumn = int32(obj.coordinates{end}(2) + 100);
      
      compositeImage = zeros(maxRow, maxColumn, 'uint32');

      iMax = size(obj.rawData{1}, 1);
      jMax = size(obj.rawData{1}, 2);
  
      for i = 1:iMax
        for j = 1:jMax

          v = sub2ind([iMax, jMax], i, j);
          if isempty(obj.coordinates{v})
            continue
          end

          if idx == 0
            img = ones(size(obj.rawData{1}{i, j}));
          else
            img = obj.rawData{idx}{i, j};
          end
          [h, w] = size(img);
          row = round(obj.coordinates{v}(1));
          col = round(obj.coordinates{v}(2));
      
          compositeImage(row:row+h-1, col:col+w-1) = img;
        end
      end

      if idx != 0
        nr = normalizer(obj.rawData);
        normalizedImage = nr.normalize(compositeImage);
      else
        normalizedImage = mat2gray(compositeImage);
      end

      %% noise removal
      %se = strel('disk', 5, 0);
      %normalizedImage = medfilt2(normalizedImage);
      %background = imopen(normalizedImage, se);
      %normalizedImage = normalizedImage - background;
      %normalizedImage(normalizedImage < 0.2) = 0;
      
      name = strcat('O', num2str(idx), '.png');
      outputFileName = fullfile(obj.outputDir, name);
      imwrite(normalizedImage, outputFileName);
    endfunction

    function writeComposite(obj)
      pathZero = fullfile(obj.outputDir, 'O0.png');
      pathOne = fullfile(obj.outputDir, 'O1.png');
      pathTwo = fullfile(obj.outputDir, 'O2.png');

      frame = imread(pathZero)==0;
      A = imread(pathOne);
      B = imread(pathTwo);

      A = A - A.*frame + frame * intmax('uint16');
      B = B - B.*frame + frame * intmax('uint16');
      
      C = cat(3, B, A, frame * intmax('uint16'));
      
      outputPath = fullfile(obj.outputDir, 'fused.png');
      imwrite(C, outputPath);
    endfunction

    function writeGraph(obj)
      backgroundImagePath = fullfile(obj.outputDir, 'fused.png');
      fileNameOut = "graph.png";
      img = imread(backgroundImagePath);
      img = rgb2gray(img);
      f = figure('visible', 'off'); hold on; axis equal;
      imshow(img, 'Colormap', gray(255));
      axis image; axis ij;
      for i = 1:length(obj.adjacency)
        A = obj.coordinates{obj.adjacency(i, 1)} + 75;
        B = obj.coordinates{obj.adjacency(i, 2)} + 75;
        
        line([A(2), B(2)], [A(1), B(1)], 'LineWidth', 3, 'Color', 'yellow', 'marker', 's', 'markerfacecolor', 'yellow');
      end
      outputFileName = fullfile(obj.outputDir, fileNameOut);
      print(f, '-dpng', outputFileName);
      hold off;
    endfunction
  end
endclassdef
