%% animate_aotf_spectra.m
% Read a .mat file containing the AOTF spectra and write an animated GIF
% stepping through the spectrum measured at each driving frequency.
%
% The .mat file must contain:
%   spectra : intensity matrix, [nLambda x nFreq]  (or its transpose)
%   lambda  : wavelength axis in nm, [nLambda x 1]
%   freqs   : driving frequencies in Hz, [nFreq x 1]
%             (or a wf_aotf struct with a .freqs field)
%
% If you don't have this file yet, save it from your live workspace with:
%   freqs = wf_aotf.freqs(:);
%   save('aotfSpectra.mat','spectra','lambda','freqs');

clear; clc;

%% ---- User settings ----
matFile   = 'signals_vs_time_s180.mat';   % input file with spectra, lambda, freqs
gifFile   = 'aotf_spectra.gif';  % output animation
delayTime = 0.08;                % seconds between frames
holdLast  = 1.0;                 % extra pause on the final frame (s)
frameStep = 1;                   % use >1 to skip frames (e.g. 2 = every other)

%% ---- Load data (a bit forgiving about variable names) ----
S = load(matFile);

spectra = S.spectra;
lambda  = S.lambda(:);


if isfield(S,'freqs')
    freqs = S.freqs(:);
elseif isfield(S,'wf_aotf') && isfield(S.wf_aotf,'freqs')
    freqs = S.wf_aotf.freqs(:);
else
    error('No frequency vector found. Expected "freqs" or "wf_aotf.freqs".');
end

% Ensure orientation is [nLambda x nFreq]
if size(spectra,1) ~= numel(lambda) && size(spectra,2) == numel(lambda)
    spectra = spectra.';
end

assert(size(spectra,1) == numel(lambda), ...
    'spectra rows (%d) do not match lambda length (%d).', ...
    size(spectra,1), numel(lambda));
assert(size(spectra,2) == numel(freqs), ...
    'spectra columns (%d) do not match number of frequencies (%d).', ...
    size(spectra,2), numel(freqs));

nFreq = numel(freqs);

%% ---- Fixed axis limits so the animation does not jump around ----
yMin = min(spectra(:));
yMax = max(spectra(:));
pad  = 0.05*(yMax - yMin + eps);

fig = figure('Color','w');
ax  = axes(fig);

firstWrite = true;
frames = 1:frameStep:nFreq;

for k = frames
    plot(ax, lambda, spectra(:,k), 'LineWidth', 1.5);
    xlim(ax, [min(lambda) max(lambda)]);
    ylim(ax, [yMin-pad yMax+pad]);
    xlabel(ax, 'Wavelength [nm]');
    ylabel(ax, 'Intensity');
    title(ax, sprintf('AOTF spectrum  —  f = %.3f MHz   (%d/%d)', ...
        freqs(k)*1e-6, k, nFreq));
    grid(ax, 'on'); box(ax, 'on');
    drawnow;

    % Capture the current figure and convert to an indexed image
    frame     = getframe(fig);
    [A, map]  = rgb2ind(frame2im(frame), 256);

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