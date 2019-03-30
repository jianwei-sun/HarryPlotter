classdef HarryPlotter < handle
    properties(Access = public)
        % Padding between all drawable areas in plot (pixels)
        padding = 10;
        name;
    end
    
    properties(Access = private)
        fig;
        
        % Plotting grid and size
        rows;
        cols;
        gridMatrix;
        
        % Plot handles
        plots = [];
        
        % Size of each drawable block. Recalculated on each resize
        blockWidth;
        blockHeight;
    end
   
    methods(Access = public)
        %
        % Constructor
        %
        function obj = HarryPlotter(arg1, arg2, arg3)
            % Determine how the constructor is called
            switch(nargin)
                case 1
                    name = arg1;
                    rows = 1;
                    cols = 1;
                case 2
                    name = "No Name";
                    rows = arg1;
                    cols = arg2;
                case 3
                    name = arg1;
                    rows = arg2;
                    cols = arg3;
                otherwise
                    name = "No Name";
                    rows = 1;
                    cols = 1;
            end
            % Figure name
            if(ischar(name))
                name = string(name);
            end
            if(isstring(name))
                obj.name = name;
            else
                error("Name must be a string.");
            end
            % Figure grid matrix
            if(isnumeric(rows) && isnumeric(cols))
                if(rows >= 1 && cols >= 1)
                    obj.rows = rows;
                    obj.cols = cols;
                    obj.gridMatrix = false(round(rows), round(cols));
                else
                    error("Rows and Cols must be greater than or equal to 1.");
                end
            else
                error("Rows and Cols must be numbers.");
            end
            % Create a new figure and get the handle. Note, calling gcf
            % will just return the currently open figure
            obj.fig = figure;
            obj.fig.Name = obj.name;
            
            % Calculate the plotting block sizes
            obj.blockWidth = floor((obj.fig.Position(3) - (obj.cols + 1) * obj.padding) / (obj.cols));
            obj.blockHeight = floor((obj.fig.Position(4) - (obj.rows + 1) * obj.padding) / (obj.rows));
            
            % Register the callback to redraw the plot on each resize
            obj.fig.SizeChangedFcn = @obj.redraw;
            
            % Register the callback when the figure window is closed
            obj.fig.CloseRequestFcn = @obj.on_window_close;
            
            if(rows == 1 && cols == 1)
                obj.subplot([1,1,1,1]);
            end
        end
        
        %
        % Destructor
        %
        function delete(obj)
            fprintf(['Deleted "', char(obj.name), '".\n']);
            delete(obj.fig);
        end
        
        %
        % Call this function to update the figure
        %
        function update(obj)
            obj.redraw();
        end
        
        %
        % Set the current plotting axes
        %
        function ax = subplot(obj, varargin)
            if(isempty(varargin))
                availability = false;
                for r = 1:obj.rows
                    for c = 1:obj.cols
                        if(~obj.gridMatrix(r, c))
                            availability = true;
                            row = r;
                            col = c;
                            break;
                        end
                    end
                    if(availability)
                        break;
                    end
                end
                if(~availability)
                    error("Plot is full.");
                end
                dimensions = [row, col, 1, 1];
            elseif(length(varargin) == 2)
                dimensions = [varargin{1}, varargin{2}, 1, 1];
            elseif(length(varargin) == 4)
                dimensions = [varargin{1}, varargin{2}, varargin{3}, varargin{4}];
            else
                error("Incorrect number of arguments.");
            end
            row = dimensions(1);
            col = dimensions(2);
            if(length(dimensions) == 4)
                height = dimensions(3);
                width = dimensions(4);
            else
                height = 1;
                width = 1;
            end
            % Check index bounds
            if(row < 1 || row > obj.rows || col < 1 || col > obj.cols || (row + height - 1) > obj.rows || (col + width - 1) > obj.cols)
                error("Selected plotting area has index errors.");
            end
            % Check if region already contains another plot
            for r = row:(row + height - 1)
                for c = col:(col + width - 1)
                    if(obj.gridMatrix(r, c))
                        error("Selected plotting area already contains another plot.");
                    end
                end
            end

            % Create the plot at the specified location and mark the area as unavilable
            ax = axes;
            ax.Units = 'pixels';
            for r = row:(row + height - 1)
                for c = col:(col + width - 1)
                    obj.gridMatrix(r,c) = true;
                end
            end
            % Store handle information
            numPlots = length(obj.plots);
            obj.plots(numPlots + 1).handle = ax;
            obj.plots(numPlots + 1).start = [row, col];
            obj.plots(numPlots + 1).size = [height, width];
            
            % Update the plot
            obj.redraw();  
        end
        
        %
        % Retrieve a particular axis
        %
        function handle = get_axis(obj, index)
            if(~isnumeric(index) || index < 1 || index > length(obj.plots))
                error("Invalid argument.");
            end
            handle = obj.plots(index).handle;
        end
        
        %
        % Remove an axis or axes
        %
        function clear(obj, varargin)
            switch length(varargin)
                case 0
                    if(~isempty(obj.plots))
                        delete(obj.plots(length(obj.plots)).handle);
                        % clear the grid matrix rows and columns to free
                        % the area
                        obj.plots(length(obj.plots)) = [];
                    end
                case 1
                    index = varargin{1};
                    if(~isnumeric(index) || index < 1 || index > length(obj.plots))
                        error("When providing single argument, it must be a valid index");
                    end
                    delete(obj.plots(index).handle);
                    obj.plots(index) = [];
                case 2
                    
                case 4
                    
                otherwise
                    error("Invalid number of arguments.");
            end
            
        end
        
%         %
%         % Plot titles
%         %
%         function title(obj, varargin)
%             [plotIndex, varargin] = obj.parse_varargin(varargin{:});
%             title(obj.plots(plotIndex).handle, varargin{:});
%             obj.redraw();
%         end
%         
%         %
%         % Defining X, Y, Z labels
%         %
%         function xlabel(obj, varargin)
%             obj.label('x', varargin{:});
%         end
%         function ylabel(obj, varargin)
%             obj.label('y', varargin{:});
%         end
%         function zlabel(obj, varargin)
%             obj.label('z', varargin{:});
%         end
%         
%         %
%         % Simple plotter for plotting at next available area
%         %
%         function handle = plot(obj, varargin)            
%             availability = false;
%             for r = 1:obj.rows
%                 for c = 1:obj.cols
%                     if(~obj.gridMatrix(r, c))
%                         availability = true;
%                         row = r;
%                         col = c;
%                         break;
%                     end
%                 end
%                 if(availability)
%                     break;
%                 end
%             end
%             if(~availability)
%                 error("Plot is full.");
%             end
%             handle = obj.plot_at([row, col, 1, 1], varargin{:});
%         end
%         
%         %
%         % Simple plotter for specifying where to plot
%         %
%         function handle = plot_at(obj, dimensions, varargin)
%             % First argument specifies the location and size of the plot
%             if(length(dimensions) ~= 4 && length(dimensions) ~= 2)
%                 error("Incorrect dimensions. Expected [starting row, starting column, height, width] or [starting row, starting column].");
%             end
%             row = dimensions(1);
%             col = dimensions(2);
%             if(length(dimensions) == 4)
%                 height = dimensions(3);
%                 width = dimensions(4);
%             else
%                 height = 1;
%                 width = 1;
%             end
%             % Check index bounds
%             if(row < 1 || row > obj.rows || col < 1 || col > obj.cols || (row + height - 1) > obj.rows || (col + width - 1) > obj.cols)
%                 error("Selected plotting area has index errors.");
%             end
%             % Check if region already contains another plot
%             for r = row:(row + height - 1)
%                 for c = col:(col + width - 1)
%                     if(obj.gridMatrix(r, c))
%                         error("Selected plotting area already contains another plot.");
%                     end
%                 end
%             end
% 
%             % Create the plot at the specified location and mark the area as unavilable
%             ax = axes;
%             ax.Units = 'pixels';
%             for r = row:(row + height - 1)
%                 for c = col:(col + width - 1)
%                     obj.gridMatrix(r,c) = true;
%                 end
%             end
%             % Store handle information
%             numPlots = length(obj.plots);
%             obj.plots(numPlots + 1).handle = ax;
%             obj.plots(numPlots + 1).start = [row, col];
%             obj.plots(numPlots + 1).size = [height, width];
%             
%             % Update the plot
%             obj.redraw();
%             
%             % Plot at the axes
%             plot(ax, varargin{:});
%             
%             % Return a plot index
%             handle = length(obj.plots);
%         end
    end
   
    methods(Access = private)
%         %
%         % Creating plot labels
%         %
%         function label(obj, axis, varargin)
%             [plotIndex, varargin] = obj.parse_varargin(varargin{:});
%             switch axis
%                 case 'x'
%                     xlabel(obj.plots(plotIndex).handle, varargin{:});
%                 case 'y'
%                     ylabel(obj.plots(plotIndex).handle, varargin{:});
%                 case 'z'
%                     zlabel(obj.plots(plotIndex).handle, varargin{:});
%             end
%             obj.redraw();
%         end
%         
%         %
%         % Parsing varargin with plot index
%         %
%         function [plotIndex, varargin] = parse_varargin(obj, varargin)
%             if(isempty(varargin))
%                 varargin = {length(obj.plots)};
%             end
%             if(isnumeric(varargin{1}))
%                 plotIndex = varargin{1};
%                 varargin = {varargin{2:end}};
%                 if(isempty(varargin))
%                     varargin = {''};
%                 end
%             else
%                 plotIndex = length(obj.plots);
%             end
%             if(plotIndex < 1 || plotIndex > length(obj.plots))
%                 error("Plot index does not exist.");
%             end
%         end
        
        %
        % Closing figure window
        %
        function on_window_close(obj, varargin)
            delete(obj);
        end
        
        %
        % Window size change callback function to redraw the positions of all axes
        %
        function obj = redraw(obj, varargin)
            % Calculate the new block sizes
            obj.blockWidth = floor((obj.fig.Position(3) - (obj.cols + 1) * obj.padding) / (obj.cols));
            obj.blockHeight = floor((obj.fig.Position(4) - (obj.rows + 1) * obj.padding) / (obj.rows));
            % Loop through all the plots and draw them
            for i = 1:length(obj.plots)
                obj.plots(i).handle.Position = [(obj.plots(i).start(2) - 1) * (obj.blockWidth + obj.padding) + obj.padding + obj.plots(i).handle.TightInset(1), ...
                                                (obj.rows - obj.plots(i).size(1) - obj.plots(i).start(1) + 1) * (obj.blockHeight + obj.padding) + obj.padding + obj.plots(i).handle.TightInset(2), ...
                                                obj.plots(i).size(2) * obj.blockWidth + (obj.plots(i).size(2) - 1) * obj.padding - (obj.plots(i).handle.TightInset(1) + obj.plots(i).handle.TightInset(3)), ...
                                                obj.plots(i).size(1) * obj.blockHeight + (obj.plots(i).size(1) - 1) * obj.padding - (obj.plots(i).handle.TightInset(2) + obj.plots(i).handle.TightInset(4)) ...
                                               ];
                grid(obj.plots(i).handle, 'on');
                box(obj.plots(i).handle, 'on');
            end
        end
    end
end