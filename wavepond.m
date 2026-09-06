classdef wavepond < handle
    % Wavepond AWG control class
    %
    % Uses the wavepondWF class to generate appropriate waveforms to be
    % used here
    
    properties (Constant)
        
        libpath = 'D:\Coding\ChLabGit\pa_rig\wavepond\wavepond_files\Win7_64_bit\';
        libname = 'dax22000_lib_DLL64';
        dllname = 'dax22000_lib_DLL64.dll';
        headername = 'dax22000_lib_DLL64_tom.h';
        
    end
    
    properties (SetAccess = private)
        card % Wavepond AWG card handle
        numCards % Number of Wavepond AWG cards
        trigNow = 0; % Add software trigger to start things off. Otherwise a trigger must be supplied somewhere else like software trigger or external trigger
        ser % Wavepond AWG card serial number
        err % Error code
        isRunning = 0; % Is Wavepond AWG card running ?
    end
    
    properties
        sampleRate = 500e6; % AWG sample rate
        extTrig = 1; % Sets an external trigger if true
    end
    
    methods
        function obj = wavepond()
            % Class constructor: loads libraries, initiate and initializes connection
            
            % Try to load the library
            obj.LoadDll();
            
            % Setup Wavepond
            obj.GetNumCards();
            obj.SetActiveCard(1);
            obj.GetSerial(); % Returns the serial number of the card founds
            obj.OpenCard(); % Opens the card found (returns 0 if successful)
            obj.Initialize; % Initializes the USB controller (returns 0 if successful)
            
            % todo: pass trig and clock params as inputs
            obj.SetClkRate();
            obj.SelExtTrig(); % Selects an external trigger if obj.trig is true (returns 0 if successful)
            
            fprintf('Wavepond system is set up. Now, waveforms have to be loaded.\n');
        end
        
        
        function CreateSingleSegment(obj, channel, waveform, numLoops, trigVal)
            % Create a segment waveform in the card memory
            %
            % This call provides the simplest way to create a continuous waveform looping on itself (NumLoops = 0)
            % or a single triggered waveform
            %
            % Input(s) (mandatory):
            %   * channel: channel number (1 or 2)
            %   * waveform: waveform array (must be integers between 0 and 4095)
            %   * numLoops: number of loops (0 = infinite loops, otherwise between 1 and 65534)
            %   * trigVal: trigger value (0 or 1, 0 = cannot be retriggered, 1 = can be retriggered)
            
            obj.err = calllib(obj.libname, 'DAx22000_CreateSingleSegment', ...
                obj.card, ... % Card number (1 <= x <= 4)
                channel, ... % Channel number (1 or 2)
                numel(waveform), ... % Number of points (48 <= x <= MaxMemory - 1024) [must be modulo 16]
                numLoops, ... % Number of loops (1 <= x <= 65,534) [0 = continuous loop]
                2047, ... % Padding value (before) (0 <= x <= 4095) -> seems like it is not working...
                2047, ... % Padding value (after) (0 <= x <= 4095)
                uint16(waveform), ... % Array of points to generate (unsigned short)
                trigVal ); % Trigger: 0 or 1. 0 => Waveform starts up first time but cannot be triggerd later without shutting down first. 1 => Allows waveform to be triggered more than once while running.
            
            % setting to zero the other channel since weird behavior has been observed
            obj.err = calllib(obj.libname, 'DAx22000_CreateSingleSegment', ...
                obj.card, ... % Card number (1 <= x <= 4)
                1+mod(channel,2), ... % get the other channel
                numel(waveform), ... % Number of points (48 <= x <= MaxMemory - 1024) [must be modulo 16]
                numLoops, ... % Number of loops (1 <= x <= 65,534) [0 = continuous loop]
                2047, ... % Padding value (before) (0 <= x <= 4095) 
                2047, ... % Padding value (after) (0 <= x <= 4095)
                2047+0*uint16(waveform), ... % Array of points to generate (unsigned short)
                trigVal ); % Trigger: 0 or 1. 0 => Waveform starts up first time but cannot be triggerd later without shutting down first. 1 => Allows waveform to be triggered more than once while running.
            
%             disp(['active: ' num2str(channel) ' - inactive: ' num2str(1+mod(channel,2))])
            
        end
        
         function CreateSingleSegmentOnBothChannels(obj, waveform1, waveform2, numLoops, trigVal)
            % Create two segment waveforms (one for each channel) in the card memory
            %
            % This call provides the simplest way to create a continuous waveform looping on itself (NumLoops = 0)
            % or a single triggered waveform
            %
            % Input(s) (mandatory):
            %   * waveform1: waveform array for channel 1 (must be integers between 0 and 4095)
            %   * waveform2: waveform array for channel 2 (must be integers between 0 and 4095)
            %   waveform1 and waveform2 should have the exact same length
            %   * numLoops: number of loops (0 = infinite loops, otherwise between 1 and 65534)
            %   * trigVal: trigger value (0 or 1, 0 = cannot be retriggered, 1 = can be retriggered)
            
            if length(waveform1)~=length(waveform2)
                error('The two waveforms should have the same length.')
            end 
            
            obj.err = calllib(obj.libname, 'DAx22000_CreateSingleSegment', ...
                obj.card, ... % Card number (1 <= x <= 4)
                1, ... % Channel number (1 or 2)
                numel(waveform1), ... % Number of points (48 <= x <= MaxMemory - 1024) [must be modulo 16]
                numLoops, ... % Number of loops (1 <= x <= 65,534) [0 = continuous loop]
                2047, ... % Padding value (before) (0 <= x <= 4095) -> seems like it is not working...
                2047, ... % Padding value (after) (0 <= x <= 4095)
                uint16(waveform1), ... % Array of points to generate (unsigned short)
                trigVal ); % Trigger: 0 or 1. 0 => Waveform starts up first time but cannot be triggerd later without shutting down first. 1 => Allows waveform to be triggered more than once while running.
            
            obj.err = calllib(obj.libname, 'DAx22000_CreateSingleSegment', ...
                obj.card, ... % Card number (1 <= x <= 4)
                2, ... % get the other channel
                numel(waveform2), ... % Number of points (48 <= x <= MaxMemory - 1024) [must be modulo 16]
                numLoops, ... % Number of loops (1 <= x <= 65,534) [0 = continuous loop]
                2047, ... % Padding value (before) (0 <= x <= 4095) 
                2047, ... % Padding value (after) (0 <= x <= 4095)
                uint16(waveform2), ... % Array of points to generate (unsigned short)
                trigVal ); % Trigger: 0 or 1. 0 => Waveform starts up first time but cannot be triggerd later without shutting down first. 1 => Allows waveform to be triggered more than once while running.
%             disp(['active: ' num2str(channel) ' - inactive: ' num2str(1+mod(channel,2))])
         end
        
        function Run(obj)
            % Run the card and output the waveforms that have been set in
            % card memory
            obj.err = calllib(obj.libname, 'DAx22000_Run', obj.card, obj.trigNow);
            obj.isRunning = 1;
        end
        
        
        function SelExtTrig(obj)
            % Selects an external trigger if true (returns 0 if successful)
            obj.err = calllib(obj.libname, 'DAx22000_SelExtTrig', obj.card, obj.extTrig);
        end
        
        
        function SoftTrigger(obj)
            % This is to be called in further loops, not in init;
            % Software trigger: works whether or not the external trigger is enabled (returns 0 if successful)
            obj.err = calllib(obj.libname, 'DAx22000_SoftTrigger', obj.card);
        end
        
        
        function Stop(obj)
            % Stops outputting the waveforms stored into memory
            obj.err = calllib(obj.libname, 'DAx22000_Stop', obj.card);
            obj.isRunning = 0;
        end
        
        
        function Close(obj)
            % Close communication with the card
            obj.err = calllib(obj.libname, 'DAx22000_Close', obj.card);
        end
        
        
        function PWR_DWN(obj)
            % Power downs the card
            %
            % Does not seem to work although not returning any error
            obj.err = calllib(obj.libname, 'DAx22000_PWR_DWN', obj.card);
        end
        
        
        function delete(obj,opts)
            % Deletes the object
            % Stops the card, closes communication, and powers down the card
            arguments
                obj
                opts.PWR_DWN_Flag (1,1) {mustBeNumericOrLogical} = true;
            end
            
            obj.Stop();
            if opts.PWR_DWN_Flag
                obj.PWR_DWN();
            end
            obj.Close();
            disp(['Error code on deleting wavepond object = ' num2str(obj.err)])
            if obj.err~=0 && obj.err~=1 % when error code is 1, seems like gen obj can still be created again afterwards
                warning('DAx22000 could not be closed properly.')
                %               break
            end
            
        end
    end
    
    methods (Access = private)
        function LoadDll(obj)
            % Loads the library
            if libisloaded(obj.libname)
                unloadlibrary(obj.libname)
            end
            [notfound,warnings] = loadlibrary([obj.libpath obj.dllname], [obj.libpath obj.headername]);
            fprintf('Wavepond library is successfully loaded.\n');
        end
        
        
        function GetNumCards(obj)
            % Gets the number of cards
            obj.numCards = calllib(obj.libname, 'DAx22000_GetNumCards');
            fprintf('%d card(s) found\n', obj.numCards);
            
            if obj.numCards==0
                error('No Wavepond card found, or card is in use!');
            end
        end
        
        function SetActiveCard(obj, cardNumber)
            % Sets the active card
            if cardNumber > obj.numCards
                error(['Only ' num2str(obj.numCards) ' have been found. You cannot use the card number ' num2str(cardNumber) ' !'])
            else
                obj.card = obj.numCards(cardNumber);
            end
        end
        
        function GetSerial(obj)
            % Returns the serial number of the card founds
            obj.ser = calllib(obj.libname, 'DAx_SerNum', obj.card);
        end
        
        function OpenCard(obj)
            % Opens the card found (returns 0 if successful)
            obj.err = calllib(obj.libname, 'DAx22000_Open', obj.card);
        end
        
        function Initialize(obj)
            % Initializes the USB controller and the internal registers (returns 0 if successful),
            % Must be called after opening
            obj.err = calllib(obj.libname, 'DAx22000_Initialize', obj.card);
        end
        
        function SetClkRate(obj)
            % Sets the sampling rate of the card (returns the actual set value)
            obj.sampleRate = calllib(obj.libname,'DAx22000_SetClkRate',obj.card,obj.sampleRate);
        end
        
%         function enableExt10MHz(obj)
%             % enables external reference clock at 10MHz (3Vpp TTL signal)
%             obj.err = calllib(obj.libname,'DAx22000_Ext10MHz',obj.card,1);
%         end
%         
%         function disableExt10MHz(obj)
%             % disables external reference clock at 10MHz (3Vpp TTL signal)
%             obj.err = calllib(obj.libname,'DAx22000_Ext10MHz',obj.card,0);
%         end
    end
end

