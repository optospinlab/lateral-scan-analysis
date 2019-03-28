classdef normalizer
  properties
    %%flatData;
    mode;
    mean;
    median;
    std;
    min;
    max;
    aboveModeStd;
    a;
    b;
  endproperties
  methods
    function obj = normalizer(rawData)
      [H, W] = size(rawData{1});
      [h, w] = size(rawData{1}{1, 1});
      flatData = zeros(0, 0, 0, 'uint32');
      mins = [];
      maxs = [];
      for o = 1:length(rawData)
        fl = [];
        for i = 1:H
          for j = 1:W
            tile = rawData{o}{i, j};

            se = strel('disk', 1, 0);
            img = imtophat(mat2gray(tile), se) > .2;
            %% img = mat2gray(tile);
            
            a = min(max(img * tile));
            b = max(max(img * tile));
            if (a > 0)
              mins = [a mins];
            endif

            if (b > 0)
              maxs = [b maxs];
            endif

            fl = [fl rawData{o}{i, j}];
          end
        end
        flatData(o, 1:size(fl, 1), 1:size(fl,2)) = fl;
      end

      allData = flatData(:);
      obj.mode = mode(allData);
      obj.mean = mean(flatData);
      obj.median = median(allData);
      obj.std = std(allData);
      obj.min = min(allData);
      obj.max = max(allData);

      aboveModeData = allData(allData > obj.mode);
      obj.aboveModeStd = std(aboveModeData);
      %%mode(aboveModeData)
      %%obj.std
      obj.a = mode(mins);
      obj.b = mode(maxs);
      obj.a
      obj.b
    endfunction

    function normalizedData = normalize(obj, data)
      %%normalizedData = mat2gray(data, [obj.mode, obj.mode + 3*obj.aboveModeStd]);
      normalizedData = mat2gray(data, [obj.a/2, obj.b/1.3]);
    endfunction
  end
endclassdef
