%{
    Calibrate the AOTF using the Wavepond generator and an RF Power
    Amplifier to driving it.

    RF PA : AMPA-B-34-10.500 from AA Opto-Electronic
    
    Wavepond object amplitude to output 11 Vpp at 80 MHz : 0.14.
    Make sure not to burn it !
%}
% error('there is an unidentified issue in the width computation, please investigate')
% ok, this is due to riples in the spectrum, define a min distance between
% maxima to get rid of this
try aotfGUI.gen.delete(); end
try gen.delete(); end % to prevent connection error with Wavepond generator
try osa.delete(); end 

% kill existing wavepond object if already exist
delAllWavepond();
pause(1)

clearvars -except mysys
username = mysys.user;
folder = mysys.paths.daily; % makeMyDay(username);

% Store setup related informations for saving
setup = struct('acq',[],'us',[],'opt',[]);
setup.acq = {'TW1064R2F-1B','Yokogawa'};
setup.opt = Opt_Setup_2021Q1; % Optical setup


%% Create signals to generate using the wavepond and start communicating with it
wf_aotf.regime = 'cw';
wf_aotf.type = 'sine';

% wf_aotf.freqs = linspace(79.5,81.5,100)*1e6;
% wtf happened here for some reason the aotf frequencies changed
wf_aotf.freqs = linspace(78.8,80.5,100)*1e6; 

wf_aotf.frequency = 80e6;
wf_aotf.amplitude = 0.14; % Do not exceed or you might burn the AOTF
wf_aotf.durTarget = 100e-6;
sig_aotf = wavepondWF(wf_aotf);
sig_aotf.PlotWF()

gen = wavepond();
gen.CreateSingleSegment(1,sig_aotf.waveform,0,1); % Infinite waveform sequence, on channel 1


%% Get the spectrometer ready
osa = YokogawaOSA();%'ip','10.48.20.245');
osa.SetASEDefaults();
osa.PlotSpectrum();

%% ---------------------------------- Oscilloscope configuration ------------------------------%%
% Oscilloscope Initialization for HF MHz with RF switch
ipAddress = '10.48.7.251';
osc = T3DSO2502A(ipAddress);
osc.setInputBufferSize(2^22);   % Increase input buffer size to 4MB
osc.setTimeout(60);             % Set timeout to 60 seconds
osc.connect();
% horizontal settings "time scale"
timeScale = 2e-6; % time per division
numberDivisions = 10;
totalSpan = timeScale * numberDivisions;
osc.setTimeScale(timeScale);
osc.setTimebaseDelay(-totalSpan/2);
% acquisition and triggering
osc.setImpedance(1,'FIFT')%50 Ohms
osc.setImpedance(2,'FIFT')%50 Ohms
osc.setImpedance(3,'FIFT')%50 Ohms
osc.setAcquisitionType('NORM');
osc.setTriggerType('EDGE');
osc.setTriggerLevel(720e-3);
osc.setVerticalScale(1, 1);
osc.setVerticalScale(2, 500e-3);
osc.setVerticalScale(3, 1);
%osc.setFunctionVerticalScaleAve(2,200e-3)
osc.setOffset(1,0);
osc.setOffset(2,0);
osc.setOffset(3,0);
osc.setOffset(4,0);
pause(1);
% Confirm what the oscilloscope applied
Fs_actual = osc.getSampleRate();
fprintf('Oscilloscope sample rate set to: %.2f MSa/s\n', Fs_actual/1e6);
totalTime = timeScale * 10; % 10 divisions
adcMaxValue = 2^16;     % 16-bit ADC resolution

%% Frequency loop to measure spectra
c = clock;
subfolder = sprintf('%02ih%02im',c(4),c(5));
subfolder = fullfile(folder,subfolder);

data_all = cell(1,length(wf_aotf.freqs));
t = []; 

progressbar('f scan progress (aotf frequencies)')

for f=1:length(wf_aotf.freqs)
    % Generate the sinewave for the AOTF
    wf_aotf.frequency = wf_aotf.freqs(f);
    sig_aotf = wavepondWF(wf_aotf);    
    gen.CreateSingleSegment(2,sig_aotf.waveform,0,1);
                
    gen.Run();
    gen.SoftTrigger();
    pause(0.0001)

    % Acquire the spectrum
    osa.SweepAndRetrieve();
    spectra(f,:) = osa.data.Y;

    osc.resetAveragingByOffset(3); % This need to be change based on Channel and the offset level
    pause(10);  % Wait for motor to settle 10 second chosen for 1024 trace for average
    % Acquire data
    [data, t] = acquire_single_trace(osc, adcMaxValue, Fs_actual, t);
    data_all{f} = data;
    
    % Stop the generation from the Wavepond
    gen.Stop();
    
    progressbar(f/length(wf_aotf.freqs)); % Update progressbar
end



%% Rebuild spectra
spectra = spectra.';

%% save all data related to the spectra
freqs = wf_aotf.freqs(:);
save('aotfSpectra.mat','spectra','lambda','freqs');
%% save the optical signals
save('signals_vs_time.mat','data_all','t','freqs','Fs_actual','-v7.3');

%%
% %% Plot data
% lambda = (osa.data.X*1e9)';
% figure(1);
% imagesc(wf_aotf.freqs*1e-6,lambda,spectra);
% xlabel('Driving frequency [MHz]');
% ylabel('Wavelength [nm]');
% title('Spectrum vs driving frequency')
% colorbar
% 
% 
% %% Extract peak wavelength vs driving frequency linear coefficients (fit)
% fd = find(wf_aotf.freqs>=79.5e6 & wf_aotf.freqs<=81e6);
% [valLambdaMax,idxLambdaMax] = max(spectra(:,fd),[],1);
% x = wf_aotf.freqs(fd)*1e-6;
% y = lambda(idxLambdaMax);
% f = fit(x.',y.','poly1','Robust','Bisquare');
% 
% figure(2),clf,hold on
% p1 = plot(x,y);
% pf = plot(f,x,y);
% xlabel('Driving frequency [MHz]');
% ylabel('Peak wavelength [nm]');
% title('Peak wavelength vs AOTF driving frequency')
% box on, grid on
% legend([pf(1) pf(2)],{'Data',['Fit: \lambda_{nm} = ' num2str(f.p1) '\times f_{MHz} + ' num2str(f.p2)]},'Location','Northeast')
% 
% 
% %% Extract FWHM vs driving frequency
% w = nan(length(wf_aotf.freqs(fd)),1);
% for i=1:length(wf_aotf.freqs(fd))
%     sig = spectra(:,fd(i));
%     [pks,locs,widths,proms] = findpeaks(sig,'WidthReference','halfheight');
%     [maxProm,maxPromIdx] = max(proms);
%     w(i) = widths(maxPromIdx);
% end
% dlambda = diff(lambda);
% dlambda = dlambda(1);
% w = w*dlambda;
% 
% % wl = -11.6*wf_aotf.freqs(fd)*1e-6 + 1953;
% 
% figure(3),clf,hold on
% p1 = plot(x,w);
% xlabel('Driving frequency [MHz]');
% ylabel('Resolution [nm]');
% title('Line width vs AOTF driving frequency')
% box on, grid on
% 
% 
% %% Saving
% % Prepare folders
% path = mysys.paths.daily;
% folder = sprintf('aotf_calib_%02ih%02im',c(4),c(5));
% mkdir(fullfile(path,folder))
% 
% % Save plots
% timestr = sprintf('%02ih%02im%02is',c(4),c(5),floor(c(6)));
% file_prefixes = {'aotfCal_','aotfCal_lvsf_','aotfCal_resvsl_'};
% exts = {'.fig','.svg','.png'};
% 
% % Save calibration functions
% % variables should later be provided in the following units:
% % lambda in m
% % frequency in Hz 
% 
% aotfCalib_lambda2frequency = @(lambda) ((f.p2 - lambda*1e9)/(-1*f.p1)*1e6);
% 
% aotfCalib_frequency2lambda = @(frequency) (f.p1*frequency*1e-6 + f.p2);
% 
% 
% codepath = fileparts(mfilename('fullpath'));
% if ~isempty(codepath)
%     save(fullfile(codepath,'aotfCalib.mat'),'aotfCalib_lambda2frequency','aotfCalib_frequency2lambda');
%     fprintf('\n\t Saved calibration file in: %s\n', fullfile(codepath,'aotfCalib.mat'))
% else
%     save(fullfile('aotfCalib.mat'),'aotfCalib_lambda2frequency','aotfCalib_frequency2lambda');
%     fprintf('\n\t Saved calibration file in: %s\n', fullfile(pwd,'aotfCalib.mat'))
% end
% save(fullfile(path,folder,'aotfCalib.mat'),'aotfCalib_lambda2frequency','aotfCalib_frequency2lambda');
% fprintf('\t Saved calibration file in: %s\n', fullfile(path,folder,'aotfCalib.mat'))
% 
% 
% % Save everything
% for f = 1:length(file_prefixes)
%     for e = 1:length(exts)
%         saveas(figure(f),fullfile(path,folder,[file_prefixes{f} timestr exts{e}]));
%     end
% end
% 
% 
% 
% 
% 
%% Help function:
function [data, t] = acquire_single_trace(osc, adcMaxValue, Fs_actual, t_in)
    data = osc.getDataAveraged(2,1, adcMaxValue);  % channel 2 

    if isempty(t_in)
        N = length(data);
        dt = 1 / (Fs_actual/2);
        t = (0:N-1) * dt;
    else
        t = t_in;  % Use previously computed time vector
    end
end