pkg load image;

baseDir = '/home/andrew/school/lab/raw_data/';
outputDir = '/home/andrew/school/lab/processed/';

scans = struct(
            'label',
            {
             'pre',
             '950C\n10hr',
             '960C\n10hr',
             '960C\n10hr',
             '970C\n2hr',
             '970C\n20hr',
             '980C\n2hr',
             '980C\n150hr',
             '980C\n150hr',
             '1000C\n150hr',
             '1050C\n150hr',
             '1050C\n150hr'
            },
            'in',
            {
             'CVD20/CVD20_preanneal/Large scans/2017_10_31_CVD20',
             'cvd20/cvd20_10hr_950c/large scan/2018_04_03_CVD20_10hr_950C', %flip
             'cvd20/cvd20_10hr_960c/large scan/2018_06_14_CVD20_10hr_960C_V4', %flip
             'cvd20/cvd20_10hr_960c_2/large scan/CVD20_10hr_960C_2_a', 
             'cvd20/cvd20_2hr_970c/large scans/2018_07_9_CVD20_970C_2hr_XI', %flip
             'cvd20/cvd20_20hr_970c/large scans/2018_07_25_CVD20_970C_20hr',
             'cvd20/cvd20_2hr_980c/large scans/CVD20_980C_2hr', 
             'cvd20/cvd20_150hr_980c/large scan/CVD20_980_159hr_largescan',%flip
             'cvd20/cvd20_150hr_980c_2/large scans/CVD20_150hr_980_2_depth_matched', %flip
             'cvd20/cvd20_150hr_1000c/large scan', 
             'cvd20/cvd20_150hr_1050c/large scans/1050C_150hr_100um',
             'cvd20/cvd20_150hr_1050c_anneal2/large scan good (2nd)' %flip
            },
            'flip',
            {
             false,
             true,
             false,
             false,
             true,
             true,
             true,
             false,
             true,
             true,
             true,
             false
            },
            'out',
            {
             '01-preanneal',
             '02-950C_10hr',
             '03-960C_10hr_v4',
             '04-960C_10hr_2',
             '05-970C_2hr',
             '06-970C_20hr',
             '07-980C_2hr',
             '08-980C_150hr',
             '09-980C_150hr_2',
             '10-1000C_150hr',
             '11-1050C_150hr',
             '12-1050C_150hr_2'
            }
);

skip = [1 2 3 4 5 6 7 8 9 10 11 12];

%% skip = [];

for i = 1:length(scans)
  if ismember(i, skip)
    continue
  endif
  scanPath = fullfile(baseDir, scans(i).in);
  outputPath = fullfile(outputDir, scans(i).out);
  stitchLateralScan(scanPath, outputPath, scans(i).flip);
end

o1counts = [];
o2counts = [];

for i = 1:length(scans)
  scanPath = fullfile(outputDir, scans(i).out, 'fused.png');
  [c1, c2] = countDots(scanPath);
  o1counts = [o1counts c1];
  o2counts = [o2counts c2];
end

f = figure('visible', 'off');

bar([o1counts' o2counts'], 'stacked');
set(gca,'XTickLabel', {scans.label});

p = get(gca, "outerposition");

set(gca,'OuterPosition',[p(1) p(2) + 0.05 p(3) p(4) - 0.05]);
set(gca, "fontsize", 24);

print(f, '-dpng', 'counts.png', '-S1280,720');
