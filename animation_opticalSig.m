%% animate_scope_signals.m
% Step through the 50 scope signals in data_all and write an animated GIF
% of amplitude vs. time, with each signal's DC offset removed.

clear; clc;

%% ---- User settings ----
matFile   = 'signals_vs_time_s180.mat';  % input file with data_all and t
gifFile   = 'scope_signals.gif';         % output animation
delayTime = 0.08;                        % seconds between frames
holdLast  = 1.0;                         % extra pause on the final frame (s)
frameStep = 1;                           % use >1 to skip frames

%% ---- Load data ----
S = load(matFile);
data_all = S.data_all;
t        = S.t(:);          % force column, length 5000

nFrames = numel(data_all);  % 50 signals

% Sanity checks
assert(iscell(data_all), 'data_all must be a cell array.');
assert(numel(data_all{1}) == numel(t), ...
    'Signal length (%d) does not match time length (%d).', ...
    numel(data_all{1}), numel(t));

%% ---- Remove DC offset from each signal ----
data_all = cellfun(@(c) c(:) - mean(c(:)), data_all, ...
                   'UniformOutput', false);

%% ---- Fixed axis limits so the animation does not jump around ----
allData = cell2mat(cellfun(@(c) c(:), data_all(:).', 'UniformOutput', false));
yMin = min(allData(:));
yMax = max(allData(:));
pad  = 0.05*(yMax - yMin + eps);

fig = figure('Color','w');
ax  = axes(fig);
firstWrite = true;

frames = 1:frameStep:nFrames;
for k = frames
    plot(ax, t, data_all{k}, 'LineWidth', 1.5);
    xlim(ax, [min(t) max(t)]);
    ylim(ax, [yMin-pad yMax+pad]);
    xlabel(ax, 'Time [s]');
    ylabel(ax, 'Amplitude');
    title(ax, sprintf('Scope signal   (%d/%d)', k, nFrames));
    grid(ax, 'on'); box(ax, 'on');
    drawnow;

    % Capture the current figure and convert to an indexed image
    frame    = getframe(fig);
    [A, map] = rgb2ind(frame2im(frame), 256);

    isLast = (k == frames(end));
    if firstWrite
        imwrite(A, map, gifFile, 'gif', ...
            'LoopCount', Inf, 'DelayTime', delayTime);
        firstWrite = false;
    else
        thisDelay = delayTime;
        if isLast, thisDelay = holdLast; end
        imwrite(A, map, gifFile, 'gif', ...
            'WriteMode', 'append', 'DelayTime', thisDelay);
    end
end

fprintf('Saved animation to %s (%d frames)\n', gifFile, numel(frames));