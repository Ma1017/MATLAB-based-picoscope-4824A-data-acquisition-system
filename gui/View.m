classdef View < handle
    properties
        controlObj;
        modelObj;
        fig;
        UIGrid;
        ControlButtons;
        TriggerSettings;
        ChannelSettings;
        ChannelAxes;
        ToolButtons;
    end

    properties(Hidden)
        ChannelColors;
        ButtonFontSize = 13;
        LabelFontSize = 13;
        DataLineWidth = 2.0;
    end

    methods % Initialize
        % Constructor of 'View' class 
        function obj = View()
            % Make model
            obj.modelObj = Model();

            % Make controller
            obj.controlObj = Controller(obj,obj.modelObj);

            % Add listeners for events
            obj.addListeners();

            % Initialize GUI components
            obj.buildUI();

            % Bundle controller functions
            obj.attachToController(obj.controlObj);
        end

        % Add listeners
        function addListeners(obj)
            obj.modelObj.addlistener('notifier_DeviceConnectionStateChanged',@obj.changeConnectionDisplayState);
            obj.modelObj.addlistener('notifier_updateChannelRangeSettings',@obj.updateXYAxis);
            obj.modelObj.addlistener('notifier_updatePreTriggerSetting',@obj.updateXYAxis);
            obj.modelObj.addlistener('notifier_updatePostTriggerSetting',@obj.updateXYAxis);
            obj.modelObj.addlistener('notifier_clearDataAndAxes',@obj.clearDataAndAxes);
            obj.modelObj.addlistener('notifier_collectingData',@obj.updateInterfaceDuringCollection);
            obj.modelObj.addlistener('notifier_DataCollectedSuccessfully',@obj.updateChannelAxesIfHasData);
            obj.modelObj.addlistener('notifier_DataCollectedSuccessfully',@obj.updateInterfaceAfterCollection);
            obj.modelObj.addlistener('notifier_loadDataSuccessfully',@obj.updateChannelAxesIfHasData);
            obj.modelObj.addlistener('notifier_updateChannelEnable',@obj.updateChannelEnable);
            obj.modelObj.addlistener('notifier_collectionAborting',@obj.updateAfterAborting);
            obj.modelObj.addlistener('notifier_AxesNotEmpty',@obj.updateIfAxesNotEmpty);
            obj.modelObj.addlistener('notifier_updateAutoTrigger',@obj.updateAutoTrigger);
        end

        % Attach to controller functions
        function attachToController(obj,controller)
            set(obj.fig,'CloseRequestFcn',@controller.controller_closeApp);

            set(obj.ControlButtons.ConnectButton,'ButtonPushedFcn',@controller.controller_connectDevice);
            set(obj.ControlButtons.DisconnectButton,'ButtonPushedFcn',@controller.controller_disconnectDevice);
            set(obj.ControlButtons.RunButton,'ButtonPushedFcn',@controller.controller_runCollecting);
            set(obj.ControlButtons.StopButton,'ValueChangedFcn',@controller.controller_stopCaptureData);

            % Set callbacks for trigger setting widgets
            set(obj.TriggerSettings.AutoTriggerEnable,'ValueChangedFcn',@controller.controller_updateAutoTriggerEnable);
            controller.controller_updateAutoTriggerEnable();
            set(obj.TriggerSettings.AutoTrigger,'ValueChangedFcn',@controller.controller_updateAutoTriggerSetting);
            controller.controller_updateAutoTriggerSetting(obj.TriggerSettings.AutoTrigger);
            set(obj.TriggerSettings.SimpleTriggerChannel,'ValueChangedFcn',@controller.controller_updateTriggerChannel);
            controller.controller_updateTriggerChannel(obj.TriggerSettings.SimpleTriggerChannel);
            set(obj.TriggerSettings.SimpleTriggerThreshold,'ValueChangedFcn',@controller.controller_updateTriggerThreshold);
            controller.controller_updateTriggerThreshold(obj.TriggerSettings.SimpleTriggerThreshold);
            set(obj.TriggerSettings.SimpleTriggerDirection,'ValueChangedFcn',@controller.controller_updateSimpleTriggerDirection);
            controller.controller_updateSimpleTriggerDirection(obj.TriggerSettings.SimpleTriggerDirection);
            set(obj.TriggerSettings.PreTrigger,'ValueChangedFcn',@controller.controller_updatePreTrigger);
            controller.controller_updatePreTrigger(obj.TriggerSettings.PreTrigger);
            set(obj.TriggerSettings.PostTrigger,'ValueChangedFcn',@controller.controller_updatePostTrigger);
            controller.controller_updatePostTrigger(obj.TriggerSettings.PostTrigger);

            for i = 1:numel(obj.modelObj.AvailableChannels)
                ChannelName = obj.modelObj.AvailableChannels(i);
                set(obj.ChannelSettings.(ChannelName).ChannelEnable,'ValueChangedFcn',@controller.controller_updateChannelEnableCheckBox);
                controller.controller_updateChannelEnableCheckBox(obj.ChannelSettings.(ChannelName).ChannelEnable); % This line
                set(obj.ChannelSettings.(ChannelName).ChannelCoupling,'ValueChangedFcn',@controller.controller_updateChannelCouplingSetting);
                controller.controller_updateChannelCouplingSetting(obj.ChannelSettings.(ChannelName).ChannelCoupling); % This line
                set(obj.ChannelSettings.(ChannelName).ChannelRange,'ValueChangedFcn',@controller.controller_updateChannelRangeSetting);
                controller.controller_updateChannelRangeSetting(obj.ChannelSettings.(ChannelName).ChannelRange);
                set(obj.ChannelSettings.(ChannelName).ChannelOffset,'ValueChangedFcn',@controller.controller_updateChannelOffsetSetting);
                controller.controller_updateChannelOffsetSetting(obj.ChannelSettings.(ChannelName).ChannelOffset);
            end

            set(obj.ToolButtons.loadDataButton,'ButtonPushedFcn',@controller.controller_loadMatDataFile);
            set(obj.ToolButtons.clearDataAndAxesButton,'ButtonPushedFcn',@controller.controller_clearAxes);
            set(obj.ToolButtons.saveDataButton,'ButtonPushedFcn',@controller.controller_saveData);
        end

        % Construct GUI
        function buildUI(obj)
            % Create figure and uigrid
            obj.fig = uifigure('Units','pixels','Color',[1,1,1],'Position',[81,143,1745,816], ...
                'Name','MATLAB Based PicoScope 4824A Block Data Acquisition System'...,'WindowState','maximized','WindowStyle','alwaysontop'
                );

            % Create main grid
            obj.UIGrid.MainGrid = uigridlayout(obj.fig, ...
                'RowHeight',{'1x'},'ColumnWidth',{'2x','4x',100},...
                'Padding',[0,0,0,0],'ColumnSpacing',0,'RowSpacing',0);

            % Create left setting grid
            obj.UIGrid.LeftGrid = uigridlayout(obj.UIGrid.MainGrid, ...
                'RowHeight',{50,200,'1x'},'ColumnWidth',{'1x'}, ...
                'Padding',[0,0,0,0],'ColumnSpacing',0,'RowSpacing',0);

            % Create control grid
            obj.UIGrid.ControlGrid = uigridlayout(obj.UIGrid.LeftGrid,...
                'RowHeight',{'1x'},'ColumnWidth',{'1x','1x','1x','1x'});

            % Create trigger grid
            obj.UIGrid.TriggerGrid = uigridlayout(obj.UIGrid.LeftGrid,...
                'RowHeight',{'1x','1x','1x','1x','1x'},'ColumnWidth',{'1.5x','1x'});

            % Create channel setting grid
            obj.UIGrid.MainChannelSettingGrid = uigridlayout(obj.UIGrid.LeftGrid, ...
                'RowHeight',{'1x','1x','1x','1x'},'ColumnWidth',{'1x','1x'});
            obj.UIGrid.ChannelSettingGrid.A = createChannelGrid(obj.UIGrid.MainChannelSettingGrid);
            obj.UIGrid.ChannelSettingGrid.B = createChannelGrid(obj.UIGrid.MainChannelSettingGrid);
            obj.UIGrid.ChannelSettingGrid.C = createChannelGrid(obj.UIGrid.MainChannelSettingGrid);
            obj.UIGrid.ChannelSettingGrid.D = createChannelGrid(obj.UIGrid.MainChannelSettingGrid);
            obj.UIGrid.ChannelSettingGrid.E = createChannelGrid(obj.UIGrid.MainChannelSettingGrid);
            obj.UIGrid.ChannelSettingGrid.F = createChannelGrid(obj.UIGrid.MainChannelSettingGrid);
            obj.UIGrid.ChannelSettingGrid.G = createChannelGrid(obj.UIGrid.MainChannelSettingGrid);
            obj.UIGrid.ChannelSettingGrid.H = createChannelGrid(obj.UIGrid.MainChannelSettingGrid);

            % Construct axes grid
            obj.UIGrid.AxesGrid = uigridlayout(obj.UIGrid.MainGrid, ...
                'RowHeight',{'1x','1x','1x','1x'},'ColumnWidth',{'1x','1x'}, ...
                'Padding',[0,0,0,0],'ColumnSpacing',0,'RowSpacing',0);

            % Create tool grid
            obj.UIGrid.ToolGrid = uigridlayout(obj.UIGrid.MainGrid,[20,1], ...
                'Padding',[5,5,5,5]);

            % Create control widgets
            obj.ControlButtons.ConnectButton = uibutton(obj.UIGrid.ControlGrid,'Text','Connect', ...
                'FontSize',obj.ButtonFontSize,'Icon','icons\connect.png','IconAlignment','left','Enable','on');
            obj.ControlButtons.DisconnectButton = uibutton(obj.UIGrid.ControlGrid,'Text','Disconnect', ...
                'FontSize',obj.ButtonFontSize,'Icon','icons\disconnect.png','IconAlignment','left','Enable','off');
            obj.ControlButtons.RunButton = uibutton(obj.UIGrid.ControlGrid,'Text','Run',...
                'FontSize',obj.ButtonFontSize,'icon','icons\run.png','IconAlignment','left','Enable','off');
            obj.ControlButtons.StopButton = uibutton(obj.UIGrid.ControlGrid,'state','Text','Stop', ...
                'FontSize',obj.ButtonFontSize,'icon','icons\stop.png','IconAlignment','left','Enable','off','Value',0);

            % Create trigger setting widgets
            % Auto-trigger setting
            obj.TriggerSettings.AutoTriggerLabel = uilabel(obj.UIGrid.TriggerGrid, ...
                'Text','Auto trigger','FontSize',obj.LabelFontSize,'Enable','off');
            AutoTriggerGrid = uigridlayout(obj.UIGrid.TriggerGrid, ...
                'RowHeight',{'1x'},'ColumnWidth',{'1x','1x'}, ...
                'Padding',[0,0,0,0],'ColumnSpacing',0,'RowSpacing',0);
            obj.TriggerSettings.AutoTriggerEnable = uicheckbox(AutoTriggerGrid,'Text','Enable','Value',0,'Enable','off');
            obj.TriggerSettings.AutoTrigger = uispinner(AutoTriggerGrid, ...
                'step',1e2,'Value',0,'ValueDisplayFormat','%.0f ms', ...
                'Limits',[0,32767],'Editable','on','Visible','off');
            
            % Simple trigger setting (Channel)
            obj.TriggerSettings.SimpleTriggerChannelLabel = uilabel(obj.UIGrid.TriggerGrid, ...
                'Text','Simple trigger (Channel)','FontSize',obj.LabelFontSize,'Enable','off');
            obj.TriggerSettings.SimpleTriggerChannel = uidropdown(obj.UIGrid.TriggerGrid, ...
                'Items',obj.modelObj.AvailableChannels,'Enable','off', ...
                'Value','A');

            % Simple trigger setting (Threshold)
            obj.TriggerSettings.SimpleTriggerThresholdLabel = uilabel(obj.UIGrid.TriggerGrid, ...
                'Text','Simple trigger (Threshold)','FontSize',obj.LabelFontSize,'Enable','off');
            obj.TriggerSettings.SimpleTriggerThreshold = uispinner(obj.UIGrid.TriggerGrid, ...
                'step',1e2,'Value',5e2,'ValueDisplayFormat','%.0f mV', ...
                'Limits',[0,2e3],'Editable','on','Enable','off');

            % Simple trigger setting (Direction)
            obj.TriggerSettings.SimpleTriggerDirectionLabel = uilabel(obj.UIGrid.TriggerGrid, ...
                'Text','Simple trigger (Direction)','FontSize',obj.LabelFontSize,'Enable','off');
            obj.TriggerSettings.SimpleTriggerDirection = uidropdown(obj.UIGrid.TriggerGrid, ...
                'Items',["ABOVE","BELOW","RISING","FALLING","RISING_OR_FALLING"], ...
                'Value',"RISING",'Enable','off');

            % Pre-trigger sample setting
            obj.TriggerSettings.PreTriggerLabel = uilabel(obj.UIGrid.TriggerGrid, ...
                'Text','Pre-trigger samples','FontSize',obj.LabelFontSize,'Enable','off');
            obj.TriggerSettings.PreTrigger = uispinner(obj.UIGrid.TriggerGrid, ...
                'Value',1e3,'step',1e3,'ValueDisplayFormat','%.0f ms',...
                'Limits',[0,inf],'Editable','on','Enable','off');

            % Post-trigger sample setting
            obj.TriggerSettings.PostTriggerLabel = uilabel(obj.UIGrid.TriggerGrid, ...
                'Text','Post-trigger samples','FontSize',obj.LabelFontSize,'Enable','off');
            obj.TriggerSettings.PostTrigger = uispinner(obj.UIGrid.TriggerGrid, ...
                'Value',1e3,'step',1e3,'ValueDisplayFormat','%.0f ms',...
                'Limits',[1e2,inf],'Editable','on','Enable','off');

            % Create channel setting widgets
            obj.ChannelColors.A = [56,157,233]/255;
            obj.ChannelColors.B = [255,33,50]/255;
            obj.ChannelColors.C = [3,231,69]/255;
            obj.ChannelColors.D = [238,211,64]/255;
            obj.ChannelColors.E = [123,70,189]/255;
            obj.ChannelColors.F = [200,200,200]/255;
            obj.ChannelColors.G = [77,244,240]/255;
            obj.ChannelColors.H = [221,74,166]/255;
            obj.ChannelSettings.A = createChannelSettingWidgets(obj.UIGrid.ChannelSettingGrid.A,'A',obj.ChannelColors.A);
            obj.ChannelSettings.B = createChannelSettingWidgets(obj.UIGrid.ChannelSettingGrid.B,'B',obj.ChannelColors.B);
            obj.ChannelSettings.C = createChannelSettingWidgets(obj.UIGrid.ChannelSettingGrid.C,'C',obj.ChannelColors.C);
            obj.ChannelSettings.D = createChannelSettingWidgets(obj.UIGrid.ChannelSettingGrid.D,'D',obj.ChannelColors.D);
            obj.ChannelSettings.E = createChannelSettingWidgets(obj.UIGrid.ChannelSettingGrid.E,'E',obj.ChannelColors.E);
            obj.ChannelSettings.F = createChannelSettingWidgets(obj.UIGrid.ChannelSettingGrid.F,'F',obj.ChannelColors.F);
            obj.ChannelSettings.G = createChannelSettingWidgets(obj.UIGrid.ChannelSettingGrid.G,'G',obj.ChannelColors.G);
            obj.ChannelSettings.H = createChannelSettingWidgets(obj.UIGrid.ChannelSettingGrid.H,'H',obj.ChannelColors.H);

            % Create channel display axes
            obj.ChannelAxes.A = createChannelAxes(obj.UIGrid.AxesGrid,'A');
            obj.ChannelAxes.B = createChannelAxes(obj.UIGrid.AxesGrid,'B');
            obj.ChannelAxes.C = createChannelAxes(obj.UIGrid.AxesGrid,'C');
            obj.ChannelAxes.D = createChannelAxes(obj.UIGrid.AxesGrid,'D');
            obj.ChannelAxes.E = createChannelAxes(obj.UIGrid.AxesGrid,'E');
            obj.ChannelAxes.F = createChannelAxes(obj.UIGrid.AxesGrid,'F');
            obj.ChannelAxes.G = createChannelAxes(obj.UIGrid.AxesGrid,'G');
            obj.ChannelAxes.H = createChannelAxes(obj.UIGrid.AxesGrid,'H');

            % Create tool widgets
            % Create load button
            obj.ToolButtons.loadDataButton = uibutton(obj.UIGrid.ToolGrid, ...
                'Text','Load','Enable','on', ...
                'Icon','icons\load.png','IconAlignment','left');
            obj.ToolButtons.loadDataButton.Layout.Row = 18;
            obj.ToolButtons.clearDataAndAxesButton.Layout.Column = 1;

            % Create clear button
            obj.ToolButtons.clearDataAndAxesButton = uibutton(obj.UIGrid.ToolGrid, ...
                'Text','Clear','Enable','off', ...
                'Icon','icons\clear.png','IconAlignment','left');
            obj.ToolButtons.clearDataAndAxesButton.Layout.Row = 19;
            obj.ToolButtons.clearDataAndAxesButton.Layout.Column = 1;

            % Create save button
            obj.ToolButtons.saveDataButton = uibutton(obj.UIGrid.ToolGrid, ...
                'Text','Save','Enable','off', ...
                'Icon','icons\save.png','IconAlignment','left');
            obj.ToolButtons.saveDataButton.Layout.Row = 20;
            obj.ToolButtons.saveDataButton.Layout.Column = 1;

            % Create ChannelGrid for each channel
            function ChannelGrid = createChannelGrid(ParentGrid)
                ChannelGrid = uigridlayout(ParentGrid, ...
                    'RowHeight',{'1x','1x','1x'},'ColumnWidth',{'1x','1x'});
            end
            % Create channel setting widgets in obj.UIGrid.ChannelSettingGrid function
            function Widgets = createChannelSettingWidgets(ParentGrid,name,ChannelColor)
                Widgets.ChannelName = uilabel(ParentGrid, ...
                    'Text',strcat("Channel ",name), ...
                    'FontSize',obj.LabelFontSize, ...
                    'BackgroundColor',ChannelColor, ...
                    'FontColor','w', ...
                    'FontWeight','bold', ...
                    'Enable','off');
                StateGrid = uigridlayout(ParentGrid, ...
                    'RowHeight',{'1x'},'ColumnWidth',{'1x','1x'}, ...
                    'Padding',[0,0,0,0],'ColumnSpacing',0,'RowSpacing',0);
                Widgets.ChannelEnable = uicheckbox(StateGrid, ...
                    'Text','Enable', ...
                    'Value',1, ...
                    'Tag',strcat("Enable",name), ...
                    'Enable','off');
                Widgets.ChnnnelEnableLamp = uilamp(StateGrid, ...
                    'Color','Green', ...
                    'Enable','off');
                Widgets.CouplingLable = uilabel(ParentGrid, ...
                    'Text','Coupling', ...
                    'FontSize',obj.LabelFontSize, ...
                    'Enable','off');
                Widgets.ChannelCoupling = uidropdown(ParentGrid, ...
                    'Items',["DC","AC"], ...
                    'Tag',strcat("Coupling",name), ...
                    'Enable','off');
                Widgets.RangeLable = uilabel(ParentGrid, ...
                    'Text','Range', ...
                    'FontSize',obj.LabelFontSize, ...
                    'Enable','off');
                Widgets.ChannelRange = uidropdown(ParentGrid, ...
                    'value',"5 V",...
                    'Items',["10 mV","20 mV","50 mV","100 mV","200 mV","500 mV","1 V","2 V","5 V","10 V","20 V","50 V"], ...
                    'Tag',strcat("Range",name), ...
                    'Enable','off');
                Widgets.AnalogueOffsetLable = uilabel(ParentGrid, ...
                    'Text','Analogue offset', ...
                    'FontSize',obj.LabelFontSize, ...
                    'Enable','off');
                Widgets.ChannelOffset = uidropdown(ParentGrid, ...
                    'Items',"0.0", ...
                    'tag',strcat("Offset",name), ...
                    'Enable','off'); % Offset is always set to 0.0
            end

            % Create display Axes for each channel 
            function ax = createChannelAxes(AxesGrid,ChannelName)
                ax = axes('Parent',AxesGrid);
                hold(ax,"on"),box(ax,"on"),grid(ax,"on");
                title(ax,sprintf('Channel %s Block Data',ChannelName));
                xlabel(ax,'Time (ms)');
                ax.Interactions = zoomInteraction;
                ax.GridLineStyle = '--';
                ax.LineWidth = 1.2;
            end
        end

        % Update x- and y-range of the axes
        function updateXYAxis(obj,~,~)
            for i = 1:numel(obj.modelObj.AvailableChannels)
                ChannelName = obj.modelObj.AvailableChannels(i);
                channelAxes = obj.ChannelAxes.(ChannelName);

                % Set Xaxis
                xUpperLimit = obj.TriggerSettings.PreTrigger.Value+obj.TriggerSettings.PostTrigger.Value;
                xlim(channelAxes,[0,xUpperLimit])

                % Set Yaxis
                ylabel(channelAxes,sprintf("Voltage (V)"));

                switch obj.ChannelSettings.(ChannelName).ChannelRange.Value
                    case "10 mV"
                        yLimit = 10/1e3;
                    case "20 mV"
                        yLimit = 20/1e3;
                    case "50 mV"
                        yLimit = 50/1e3;
                    case "100 mV"
                        yLimit = 100/1e3;
                    case "200 mV"
                        yLimit = 200/1e3;
                    case "500 mV"
                        yLimit = 500/1e3;
                    case "1 V"
                        yLimit = 1;
                    case "2 V"
                        yLimit = 2;
                    case "5 V"
                        yLimit = 5;
                    case "10 V"
                        yLimit = 10;
                    case "20 V"
                        yLimit = 20;
                    case "50 V"
                        yLimit = 50;
                end
                
                ylim(channelAxes,[-yLimit,yLimit]);
            end
        end

        % Update the data curve in the axes after a new collection
        function updateChannelAxesIfHasData(obj,~,~)
            % Clear axes
            obj.clearAxes();

            % Plot available data curve
            for i = 1:numel(obj.modelObj.hasDataChannels)
                ChannelName = obj.modelObj.hasDataChannels(i);
                Axes = obj.ChannelAxes.(ChannelName);

                time = obj.modelObj.timeMs;
                data = obj.modelObj.hasDataStruct.(ChannelName).Data/1e3; % convert to 'V' while ploting
                plot(Axes,time,data, ... 
                    'Color',obj.ChannelColors.(ChannelName),'LineWidth',obj.DataLineWidth);
                xlim(Axes,[0,ceil(time(end))])
            end
            obj.updateIfAxesNotEmpty();
        end

        % Update the display state when the device connection state is changed
        function changeConnectionDisplayState(obj,~,~)
            if strcmp(obj.modelObj.ps4000aDeviceObj.status,'open')
                set(obj.ControlButtons.ConnectButton,'Enable','off')
                set(obj.ControlButtons.DisconnectButton,'Enable','on');
                set(obj.ControlButtons.RunButton,'Enable','on');
                set(obj.ControlButtons.StopButton,'Enable','off');

                obj.availableForSettings();
                obj.updateChannelEnable();
            else
                set(obj.ControlButtons.ConnectButton,'Enable','on')
                set(obj.ControlButtons.DisconnectButton,'Enable','off');
                set(obj.ControlButtons.RunButton,'Enable','off');
                set(obj.ControlButtons.StopButton,'Enable','off','Value',0);

                obj.unavailableForSettings();
                obj.clearDataAndAxes();
            end
        end

        % Clear data and data curve in the axes
        function clearDataAndAxes(obj,~,~)
            obj.clearData();
            obj.clearAxes();
            % Update the display state of 'clear' and 'save' button
            set(obj.ToolButtons.clearDataAndAxesButton,'Enable','off');
            set(obj.ToolButtons.saveDataButton,'Enable','off');
        end
        % Clear data function
        function clearData(obj,~,~)
            obj.modelObj.timeMs = [];
            obj.modelObj.hasDataChannels = [];
            obj.modelObj.hasDataStruct = [];
        end
        % Clear axes function
        function clearAxes(obj,~,~)
            for i = 1:numel(obj.modelObj.AvailableChannels)
                ChannelName = obj.modelObj.AvailableChannels(i);
                Axes = obj.ChannelAxes.(ChannelName);
                LineObject = findall(Axes,'type','line');
                delete(LineObject);
            end
        end

        % Listen for event that the collection is in progress
        function updateInterfaceDuringCollection(obj,~,~)
            % Update control buttons display states
            set(obj.ControlButtons.RunButton,'Enable','off');
            set(obj.ControlButtons.StopButton,'Enable','on','Value',0);

            % Update tool buttons display states
            set(obj.ToolButtons.clearDataAndAxesButton,'Enable','off');
            set(obj.ToolButtons.saveDataButton,'Enable','off');

            obj.unavailableForSettings();

            % Update 'load' button display state
            set(obj.ToolButtons.loadDataButton,'Enable','off');
        end

        % Listen for event that the collection is done
        function updateInterfaceAfterCollection(obj,~,~)
            set(obj.ControlButtons.RunButton,'Enable','on');
            set(obj.ControlButtons.StopButton,'Enable','off');
            set(obj.ToolButtons.clearDataAndAxesButton,'Enable','on');
            set(obj.ToolButtons.saveDataButton,'Enable','on');

            obj.availableForSettings();

            % Update 'load' button display state
            set(obj.ToolButtons.loadDataButton,'Enable','on');
        end

        % Listen for event that the 'Enable' checkbox value changed
        function updateChannelEnable(obj,~,~)
            EnablesArray = zeros(1,numel(obj.modelObj.AvailableChannels));
            for i = 1:numel(obj.modelObj.AvailableChannels)
                EnablesArray(i) = obj.ChannelSettings.(obj.modelObj.AvailableChannels(i)).ChannelEnable.Value;
            end
            EnabledChannelsIdx = find(EnablesArray);
            
            % Update the display appearance of channel setting widgets
            for i = 1:numel(EnablesArray)
                channel = obj.ChannelSettings.(obj.modelObj.AvailableChannels(i));
                ChannelSettingFields = fieldnames(channel);
                if EnablesArray(i)
                    set(channel.(ChannelSettingFields{3}),'Color','Green');
                    for j = 1:numel(ChannelSettingFields)-3
                        set(channel.(ChannelSettingFields{j+3}),'Visible','on');
                    end
                else
                    set(channel.(ChannelSettingFields{3}),'Color','Red');
                    for j = 1:numel(ChannelSettingFields)-3
                        set(channel.(ChannelSettingFields{j+3}),'Visible','off');
                    end
                end
            end
            
            % If a channel is disabled but the trigger is still set at the channel
            EnabledChannels = obj.modelObj.AvailableChannels(EnabledChannelsIdx);
            if sum(strcmp(obj.TriggerSettings.SimpleTriggerChannel.Value,EnabledChannels)) == 0
                WarningDialogText = strcat("Channel ",obj.TriggerSettings.SimpleTriggerChannel.Value," has been disabled, ",...
                    "so the programe automatically sets the trigger at Channel ",EnabledChannels(1),".");
                set(obj.TriggerSettings.SimpleTriggerChannel,'Value',EnabledChannels(1));
                obj.modelObj.callback_updateTriggerChannelSetting(obj.controlObj.ChannelNameMaps(EnabledChannels(1)));
                warndlg(WarningDialogText);
            end

            % If there exists only one enabled channel
            if numel(EnabledChannels) == 1
                set(obj.TriggerSettings.SimpleTriggerChannel,'Enable','off');
                set(obj.ChannelSettings.(EnabledChannels).ChannelEnable,'Enable','off');
            else
                set(obj.TriggerSettings.SimpleTriggerChannel,'Enable','on');
                for i = 1:numel(obj.modelObj.AvailableChannels)
                    set(obj.ChannelSettings.(obj.modelObj.AvailableChannels(i)).ChannelEnable,'Enable','on')
                end
            end
        end

        % Listen for event that the collection process interrupted by user
        function updateAfterAborting(obj,~,~)
            % Update display state of 'run' and 'stop' buttons
            set(obj.ControlButtons.RunButton,'Enable','on');
            set(obj.ControlButtons.StopButton,'Enable','off');

            % Update display state of 'clear' and 'save' buttons if there exists any data curve in the axes.
            for i = 1:numel(obj.modelObj.AvailableChannels)
                ChannelName = obj.modelObj.AvailableChannels(i);
                Axes = obj.ChannelAxes.(ChannelName);
                if ~isempty(findall(Axes,'type','line'))
                    set(obj.ToolButtons.clearDataAndAxesButton,'Enable','on');
                    set(obj.ToolButtons.saveDataButton,'Enable','on');
                    break
                end
            end

            obj.availableForSettings();

            % Update 'load' button display state
            set(obj.ToolButtons.loadDataButton,'Enable','on');
        end

        % Listen for event that the axes are not empty
        function updateIfAxesNotEmpty(obj,~,~)
            set(obj.ToolButtons.clearDataAndAxesButton,'Enable','on');
            set(obj.ToolButtons.saveDataButton,'Enable','on');
        end

        % Listen for event that the auto trigger setting
        function updateAutoTrigger(obj,~,~)
            if obj.TriggerSettings.AutoTriggerEnable.Value
                set(obj.TriggerSettings.AutoTrigger,'Value',1e3);
                set(obj.TriggerSettings.AutoTrigger,'Visible','on');
            else
                set(obj.TriggerSettings.AutoTrigger,'Value',0);
                set(obj.TriggerSettings.AutoTrigger,'Visible','off');
            end
        end

        function availableForSettings(obj)
            % Update trigger setting display sates
            TriggerSettingFields = fieldnames(obj.TriggerSettings);
            for i = 1:numel(TriggerSettingFields)
                set(obj.TriggerSettings.(TriggerSettingFields{i}),'Enable','on');
            end

            % Update channels setting display sates
            for i = 1:numel(obj.modelObj.AvailableChannels)
                channel = obj.ChannelSettings.(obj.modelObj.AvailableChannels(i));
                ChannelSettingFields = fieldnames(channel);
                for j = 1:numel(ChannelSettingFields)
                    set(channel.(ChannelSettingFields{j}),'Enable','on');
                end
            end
        end
        
        function unavailableForSettings(obj)
            % Update trigger setting display sates
            TriggerSettingFields = fieldnames(obj.TriggerSettings);
            for i = 1:numel(TriggerSettingFields)
                set(obj.TriggerSettings.(TriggerSettingFields{i}),'Enable','off');
            end

            % Update channels setting display sates
            for i = 1:numel(obj.modelObj.AvailableChannels)
                channel = obj.ChannelSettings.(obj.modelObj.AvailableChannels(i));
                ChannelSettingFields = fieldnames(channel);
                for j = 1:numel(ChannelSettingFields)
                    set(channel.(ChannelSettingFields{j}),'Enable','off');
                end
            end
        end
    end
end