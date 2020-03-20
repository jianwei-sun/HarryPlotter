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
                    obj.gridMatrix = zeros(round(rows), round(cols));
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
                obj.subplot(1,1,1,1);
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
            set(findall(obj.fig, '-property', 'FontSize'), 'FontSize', 14);
            graphicsObjects = findall(obj.fig, '-property', 'LineWidth');
            for i = 1:length(graphicsObjects)
                if(isa(graphicsObjects(i), 'matlab.graphics.chart.primitive.Line'))
                    graphicsObjects(i).LineWidth = 2;
                end
            end
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
                        if(obj.gridMatrix(r,c) == 0)
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
                    if(obj.gridMatrix(r,c) > 0)
                        error("Selected plotting area already contains another plot.");
                    end
                end
            end

            % Create the plot at the specified location and mark the area as unavilable
            ax = axes;
            ax.Units = 'pixels';
            for r = row:(row + height - 1)
                for c = col:(col + width - 1)
                    obj.gridMatrix(r,c) = length(obj.plots) + 1;
                end
            end
            % Store handle information
            newPlotIndex = length(obj.plots) + 1;
            obj.plots(newPlotIndex).handle = ax;
            obj.plots(newPlotIndex).start = [row, col];
            obj.plots(newPlotIndex).size = [height, width];
            
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
        % Clear all axes
        %
        function clear_all(obj)
            for index = length(obj.plots):-1:1
                obj.remove_axis(index);
            end
        end
        
        %
        % Remove an axis or axes
        %
        function clear(obj, varargin)
            switch length(varargin)
                case 0
                    if(~isempty(obj.plots))
                        obj.remove_axis(length(obj.plots));
                    end
                case 1
                    index = varargin{1};
                    if(~isnumeric(index) || index < 1 || index > length(obj.plots))
                        error("When providing single argument, it must be a valid index");
                    end
                    obj.remove_axis(index);
                case 2
                    if(varargin{1} < 1 || varargin{1} > obj.rows || varargin{2} < 1 || varargin{2} > obj.cols)
                        error("Index exceeds figure dimensions");
                    end
                    if(obj.gridMatrix(varargin{1},varargin{2}) > 0)
                        obj.remove_axis(obj.gridMatrix(varargin{1},varargin{2}));
                    end
                case 4
                    if(varargin{1} < 1 || varargin{1} > obj.rows || varargin{2} < 1 || varargin{2} > obj.cols || varargin{3} < 1 || varargin{4} < 1)
                        error("Index exceeds figure dimensions");
                    end
                    if((varargin{1} + varargin{3} - 1) > obj.rows)
                        varargin{3} = obj.rows - varargin{1} + 1;
                    end
                    if((varargin{2} + varargin{4} - 1) > obj.cols)
                        varargin{4} = obj.cols - varargin{2} + 1;
                    end
                    indicesToRemove = [];
                    for r = varargin{1}:(varargin{1} + varargin{3} - 1)
                        for c = varargin{2}:(varargin{2} + varargin{4} - 1)
                            indicesToRemove(end + 1) = obj.gridMatrix(r,c);
                        end
                    end
                    indicesToRemove = sort(unique(indicesToRemove), 'descend');
                    for i = 1:length(indicesToRemove)
                        obj.remove_axis(indicesToRemove(i));
                    end
                otherwise
                    error("Invalid number of arguments.");
            end
            obj.redraw();
        end
    end
   
    methods(Access = private)
        %
        % Deleting an axis and all associated properties
        %
        function remove_axis(obj, index)
            if(index == 0)
                return;
            end
            delete(obj.plots(index).handle);
            for r = obj.plots(index).start(1):(obj.plots(index).start(1) + obj.plots(index).size(1) - 1)
                for c = obj.plots(index).start(2):(obj.plots(index).start(2) + obj.plots(index).size(2) - 1)
                    obj.gridMatrix(r,c) = 0;
                end
            end
            for r = 1:obj.rows
                for c = 1:obj.cols
                    if(obj.gridMatrix(r,c) >= index)
                        obj.gridMatrix(r,c) = obj.gridMatrix(r,c) - 1;
                    end
                end
            end
            obj.plots(index) = [];
        end
        
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