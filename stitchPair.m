#{
Overlap type I                Overlap type II
  +------+                               +-------+
  | L +------+                      +----|--+  R |
  |   |  | R |                      | L  |  |    |
  +---|--+   |                      |    +-------+
      +------+                      +-------+
#}

function result = stitchPair(left, right)
                                % overlap type I
  [matchType1, cps1, z1] = stitchPairInternal(left, right);
                                % overlap type II
                                % (by reduction to type I)


  [matchType2, cps2, z2] = stitchPairInternal(flip(right, 2), flip(left, 2));
#{
  f = figure;
  subplot(1, 2, 1);
  colormap cool;
  shading interp;
  s = surf(cps1);
  set(s, 'edgecolor','none');
  axis ij;
  txt = strcat('\leftarrow (x=', num2str(matchType1.columnOffsetUnoptimized), ', y=', num2str(matchType1.rowOffsetUnoptimized), ')');
  text(matchType1.columnOffsetUnoptimized, matchType1.rowOffsetUnoptimized, max(cps1(:)), txt,'HorizontalAlignment','left')
  zticklabels({' '});
  xlabel("X");
  ylabel("Y");
  set (gca, 'xtick', 0:30:150);
  set (gca, 'ytick', 0:30:150);
  xlim([0, 150]);
  ylim([0, 150]);
  title('Phase cross-correlation');

  subplot(1, 2, 2);

  u = matchType1.columnOffsetUnoptimized-5:1:matchType1.columnOffsetUnoptimized+5;
  v = matchType1.rowOffsetUnoptimized-5:1:matchType1.rowOffsetUnoptimized+5;

  [x, y] = meshgrid(u, v);

  surf(x, y, shiftdim(z1,1));
  axis ij;
  xlabel("X");
  ylabel("Y");

  dx = matchType1.rowOffset;
  dy = matchType1.columnOffset;
  txt = {'local minimum'};
  text(dy, dx, 0, txt, 'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');

  title('Overlap error minimization');

  print -dpng cps.png;
#}

  %% TODO: verify
  matchType2.rowOffset = -matchType2.rowOffset;
  
  if matchType1.error < matchType2.error
    result = matchType1;
  else
    result = matchType2;
  end
end


%% Handles type I overlaps only
function [result, cps, z] = stitchPairInternal(left, right)
  overlapRatio = 1/3;

  [w, h] = size(left);

  %% assume images are squares of the same size
  %% typically 150x150 for a 50μm scan
  assert(w == h);
  assert(size(right) == [w, w]);

  cropWidth = round(w * overlapRatio);

  leftPadded = left;
  leftPadded(1:w, 1:cropWidth) = abs(randn(w, cropWidth)) * 0;
  rightCropped = right(1:w, 1:cropWidth);
  [matches, cps] = matchWithDft(leftPadded, rightCropped, 0.5);

  if (isempty(matches))
    s.error = Inf;
    s.rowOffset = 0;
    s.columnOffset = 0;
    result = [s];
    return
  end

  %% TODO try optimizing multiple reasonably good matches
  bestMatch = matches(1, :);

  s.rowOffset = bestMatch(1);

  %% TODO: is this still needed?
  %% This likely causes a bug.
  #s.rowOffset = min(s.rowOffset, w - s.rowOffset); % this should recover the row offset in case of overlap type mismatch

  s.columnOffset = bestMatch(2);

  %left = imsmooth(left, 'Average');
  %right = imsmooth(right, 'Average');
  
  [result, z] = optimize(left, right, s);
end

function [results, cpsDenorm] = matchWithDft(left, right, threshold)
  assert(threshold >= 0 & threshold < 1);
  
  w = size(left, 1);

  dft1 = fft2(left);
  dft2 = fft2(right, w, w);
  %% cross power spectrum
  dp = dft1 .* conj(dft2);
  cpsDenorm = abs(real(ifft2(dp ./ abs(dp))));

  if any(isnan(cpsDenorm(:)))
    results = [];
    return
  end
  %% find peaks in the cross power spectrum
  [v, k] = max(cpsDenorm(:));
  cps = cpsDenorm / v;
  
  cps = cps .* (cps > mean(cps) & cps >= (1 - threshold));
  
  peaks = describePeaks(cps);

  for i = 1:size(peaks, 1)
    peaks(i, 3) *= sanityScore(w, peaks(i, 1), peaks(i, 2));
  end
  %% offset is relative to the top left corner of the left image

  results = sortrows(peaks, [-3]);
end

function s = sanityScore(w, rowOffset, columnOffset)
  rowOffsetQuality = 1/2 - abs(rowOffset)/w;
  columnOffsetQuality = (columnOffset > w/2 && columnOffset/w < 0.94) * 1/2;
  s = max(rowOffsetQuality + columnOffsetQuality, 0);
end

function matches = describePeaks(cps)
  connComps = bwconncomp(cps);

  matches = [];
  for idx=1:connComps.NumObjects
    values = cps(connComps.PixelIdxList{idx});

    [peakValue, compIndex] = max(values);
    peakIndex = connComps.PixelIdxList{idx}(compIndex);

    [rowOffset, columnOffset] = ind2sub(size(cps), peakIndex);
    matches = [matches; rowOffset - 1, columnOffset - 1, peakValue];
  end
  matches = sortrows(matches, [-3]);
end

function y = meanSquaredError(M1, M2)
  %% TODO: this seems to favor smaller overlaps. How can this be
  %% adjust to be invariant to the overlap size?
  y = sum(sum((M1 - M2) .^2)) / numel(M1);
end

function [L, R] = overlap(left, right, di, dj)
  w = size(left, 1);
  i = di + 1; % NOTE: rowOffset can be negative
  j = dj + 1;

  L = left(max(1, i):min(w, w+i+1), j:w);
  R = right(max(1, -i):min(w, w-i+1), 1:w-j+1);
end

function [result, z] = optimize(left, right, match)
  w = size(left, 1);
  delta = 5;
  z = zeros(delta*2 + 1, delta*2 + 1);
  match.error = Inf;
  match.overlapEntropy = 0;

  if ((w - abs(match.rowOffset) < delta*2) || (w - match.columnOffset < delta*2) || 
      (match.columnOffset < delta*2))
    result = match;
    return
  end
  
  [dis, djs] = meshgrid(-delta:delta, -delta:delta);
  for k = 1:size(dis(:))
    [L, R] = overlap(left, right, match.rowOffset + dis(k), match.columnOffset + djs(k));
    z(k) = meanSquaredError(L, R);
  end

  match.error = min(z(:));

  z = mat2gray(z);
  %% find zero elements
  [d1s, d2s] = find(~z);
  t = min(d1s);
  b = max(d1s);
  l = min(d2s);
  r = max(d2s);

  if (t == b && t > 1 & b < size(z, 1))
    t = t - 1;
    b = b + 1;
  end

  if (l == r && l > 1 & r < size(z, 2))
    l = l - 1;
    r = r + 1;
  end

  boxSize = (b - t + 1) * (r - l + 1);
  diEx = double(sum(sum(((1 - z(t:b, l:r)) .* dis(t:b, l:r))))) / boxSize;
  djEx = double(sum(sum(((1 - z(t:b, l:r)) .* djs(t:b, l:r))))) / boxSize;

  %[v, k] = min(z(:));

  di = dis(k);
  dj = djs(k);

  di = diEx;
  dj = djEx;
  match.rowOffsetUnoptimized = match.rowOffset;
  match.columnOffsetUnoptimized = match.columnOffset;
  match.rowOffset += di;
  match.columnOffset += dj;
  
  %[L, R] = overlap(left, right, match.rowOffset, match.columnOffset);

  result = match;
end

%!demo
%! lsData = load('./test-data/CVD20_150hr_2_980C_large_scan/lsData.mat').lsData;
%! left = mat2gray(lsData(:, :, 2, 1, 9), [4000, 25000]);
%! right = mat2gray(lsData(:, :, 2, 1, 8), [4000, 25000]);
%! left = imread('./test-data/CVD20_150hr_2_980C_large_scan/O1X3Y3.png');
%! right = imread('./test-data/CVD20_150hr_2_980C_large_scan/O1X4Y3.png');
%! %left = rot90(left);
%! %right = rot90(right);
%! alignment = stitchPair(left, right);
%! alignment.rowOffset = round(alignment.rowOffset);
%! alignment.columnOffset = round(alignment.columnOffset);
%! alignment
%! left(alignment.rowOffset + 1:alignment.rowOffset + 150, alignment.columnOffset + 1:alignment.columnOffset + 150) = right;
%! imwrite(mat2gray(left), 'demo.png');
