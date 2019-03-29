function [c1, c2] = countDots(fileName)
  img = imread(fileName);
  o1 = img(:,:,1);
  o2 = img(:,:,2);
  c1 = countDotsOrientation(o1);
  c2 = countDotsOrientation(o2);
end

function r = countDotsOrientation(data)
  se = strel('disk', 2, 0);
  tophatFiltered = imtophat(data, se);

  d5 = strel('disk', 10, 0);
  background = imopen(data, d5);
  d15 = strel('disk', 15, 0);
  background = imdilate(background, d15) > 4000;

  bw = (tophatFiltered > 11000) .* ~background;
  se = strel('disk', 1, 0);
  bw2 = imerode(bw, se);
  
  r = length(find(bw2)) / length(find(~background));
end
