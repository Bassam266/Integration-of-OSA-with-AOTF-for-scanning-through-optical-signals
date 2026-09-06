# Integration of OSA with AOTF for scanning through optical signals

The code has a main function first. The AOTF must be calibrated in order to know the relationship between the RF frequency sent and the peak wavelength extracted. Since the AOTF acts like a grating, the extracted wavelength depends on the alignment between the optical axis of the AOTF crystal and the optical axis of the input optical beam. Thus, any time the AOTF is moved, it should be recalibrated. 
Secondly, we can detect precisely where the most sensitive part of the spectra that could give us a high SNR and lower NEP. Here, we are going to integrate the oscilloscope that detects the pressure via a photodetector; in this stage, the pulse-echo system should be on, and a generated ultrasound wave at a specific amplitude and frequency that we are intersted to measre it by optical signal. 


To do that, the following code helps us to automate the process for a finer step size of the filtering by AOTF, for precisily detect the most sensitive part in the spectrum:

1. The main code: aotf_calibration_wavepond_yokogawa_scope.m
2. OSA class: YokogawaOSA.m
3. Wave generator class: wavepond.m
4. Oscilloscope class: T3DSO2502A.m
5. Plot the of the spctra with the filter as a GIF: animation_OSASpctra.m
6. Plot the optical signal with the filter as a GIF: animation_opticalSig.m


