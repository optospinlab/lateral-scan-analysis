classdef normalizer
  properties
    a;
    b;
  endproperties
  methods
    function obj = normalizer(rawData)
      [H, W] = size(rawData{1});
      mins = [];
      maxs = [];
      for o = 1:length(rawData)
        for i = 1:H
          for j = 1:W
            tile = rawData{o}{i, j};

            regmax = imregionalmax(tile);
            peakValues = tile(find(regmax));
            a = min(peakValues);
            b = max(peakValues);
            if (a > 0)
              mins = [a mins];
            endif

            if (b > 0)
              maxs = [b maxs];
            endif
          end
        end
      end

      obj.a = mode(mins);
      obj.b = mode(maxs);
    endfunction

    function normalizedData = normalize(obj, data)
      normalizedData = mat2gray(data, [obj.a, obj.b]);
    endfunction
  end
endclassdef
