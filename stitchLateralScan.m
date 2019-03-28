function stitchLateralScan(inputDir, outputDir)
  pkg load image;
  
  rawData = discoverRawData(inputDir);
  %%nr = normalizer(rawData);
  %%return;
  bestAlignments = {};
  
  for i = 1:length(rawData)
    fprintf('[Orientation %d] Processing...\n', i);
    alignments = findPairwiseAlignments(rawData{i});

    if isempty(bestAlignments)
      bestAlignments = alignments;
    else
      for j = 1:length(bestAlignments)
        if isempty(bestAlignments{j})
          continue
        end
        if (bestAlignments{j}.error > alignments{j}.error)
          bestAlignments{j} = alignments{j};
        end
      end
    end
    fprintf('[Orientation %d] Done.\n', i);
  end

  [coordinates, adjacency] = computeBestAlignment(bestAlignments, numel(rawData{i}));

  p = persistence(outputDir, rawData, coordinates, adjacency);
  p.write();
end

function alignments = findPairwiseAlignments(rawData)
  iMax = size(rawData, 1);
  jMax = size(rawData, 2);

  n = 0;
  N = (iMax - 1) * jMax + (jMax - 1) * iMax;

  fprintf("0%%\r");
  alignments = {};

  for i = 1:iMax
    for j = 1:jMax
      thisImage = rawData{i, j};

      indThis = sub2ind([iMax, jMax], i, j);
      
      if j < jMax
        %% horizontal

        rightImage = rawData{i, j + 1};        
        alignment = stitchPairHorizontal(thisImage, rightImage);

        n++;
        fprintf("%.0f%%\r", n/N*100);
        
        indRight = sub2ind([iMax, jMax], i, j+1);

        alignments{indThis, indRight} = alignment;
        alignments{indRight, indThis} = alignment;
      end

      if i < iMax
        %% vertical

        bottomImage = rawData{i + 1, j};
        thisImageRotated = rot90(thisImage);
        bottomImageRotated = rot90(bottomImage);
        alignment = stitchPairHorizontal(thisImageRotated, bottomImageRotated);

        %% suppress vertical alignment scores
        %xs%alignment.error *= 1.5;
        n++;
        fprintf("%.0f%%\r", n/N*100);

        %% the alignment needs to be adjusted for the real (vertical) orientation
        t = alignment.columnOffset;
        alignment.columnOffset = -alignment.rowOffset;
        alignment.rowOffset = t;

        indBottom = sub2ind([iMax, jMax], i + 1, j);
        alignments{indThis, indBottom} = alignment;
        alignments{indBottom, indThis} = alignment;
      end
    end
  end
end

function [coordinates, adjacency] = computeBestAlignment(alignments, vertexCount)
  %% Customized "max" variant of the Prim's algorithm
  adjacency = [];
  
  edgeCount = 0;
  minRow = 1;
  minColumn = 1;

  orderedAlignments = [];
  for i = 1:size(alignments, 1)
    for j = 1:size(alignments, 2)
      if isempty(alignments{i, j})
        continue
      end
      orderedAlignments = [orderedAlignments; i j alignments{i, j}.error];
    end
  end
  orderedAlignments = sortrows(orderedAlignments, [3]);

  initialVertex = orderedAlignments(1, 1);
  S = [initialVertex];
  coordinates{initialVertex} = [1 1];

  while edgeCount < vertexCount - 1
    minError = Inf;
    for k = 1:size(orderedAlignments, 1)
      i = orderedAlignments(k, 1);
      j = orderedAlignments(k, 2);
            
      if alignments{i, j}.error < minError && ismember(i, S) && !ismember(j, S)
        alignment = alignments{i, j};
        minError = alignment.error;
        stitchEdge = [i, j];
      end
    end

    edgeCount++;
    a = stitchEdge(1);
    b = stitchEdge(2);
    
    S = [S, b];

    adjacency = [adjacency; stitchEdge];

    offset = [alignment.rowOffset alignment.columnOffset];

    if a > b
      %% this is a back edge
      offset = -offset;
    end

    coordinates{b} = coordinates{a} + offset;
    
    minRow = min(coordinates{b}(1), minRow);
    minColumn = min(coordinates{b}(2), minColumn);
  end

  %% shift
  rowShift = 1 - minRow;
  columnShift = 1 - minColumn;
  for i=1:length(coordinates)
    if (isempty(coordinates{i}))
      continue
    end
    coordinates{i} = coordinates{i} + [rowShift, columnShift];
  end
end

function alignment = stitchPairHorizontal(leftImage, rightImage)
  alignment = stitchPair(leftImage, rightImage);
  
  if alignment.error == Inf
    return
  end

  needsFlip = alignment.rowOffset < 0;
  if needsFlip
    l = flip(rightImage, 2);
    r = flip(leftImage, 2);
    rowOffset = -alignment.rowOffset;
  else
    l = leftImage;
    r = rightImage;
    rowOffset = alignment.rowOffset;
  end

  return

  combined = l;
  
  combined(1 + rowOffset:rowOffset+150,
           1 + alignment.columnOffset: alignment.columnOffset+150) = r;

  if needsFlip
    combined = flip(combined, 2);
  end
  imwrite(combined, strcat(leftImageName, '_', rightImageName, '.png'))
end

function rawData = discoverRawData(inputDir)
  lsData = load(fullfile(inputDir, 'lsData.mat')).lsData;

  %% a = load(fullfile(baseDir, 'piezoSpeed.mat')); %% does this ever change?
  %% y up x to the right

  rawData = {{}, {}};

  for o = 1:size(lsData, 3)
    for x = 1:size(lsData, 4)
      for y = 1:size(lsData, 5)
        scanData = lsData(:, :, o, x, y);
        rawData{o}{10-y, x} = scanData; %% FIXME
      end
    end
  end
end
