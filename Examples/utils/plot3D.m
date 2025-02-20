thermal = 'ThermalModel';
G = model.G;


h = figure(); 
set(h, 'Position', [10 10 1700 500]);

dovideo = false;

if dovideo
    filename = 'temperature.avi';
    video = VideoWriter(filename);
    video.FrameRate = 3;
    open(video);
end

for ind = 1 : numel(states)

    subplot(1, 2, 1);
    plotCellData(G, states{ind}.(thermal).T)
    colorbar
    view([30, 32]);
    subplot(1, 2, 2);
    plot((time(1 : ind)/hour), E(1 : ind), '*-');
    xlabel('hours');
    ylabel('E');
    axis([0, max(time)/hour, min(E), max(E)])
    
    if dovideo
        frame = getframe(gcf);
        writeVideo(video, frame);
    end
    
    pause(0.1);
    
end

if dovideo
    close(video);
end




%{
Copyright 2021-2023 SINTEF Industry, Sustainable Energy Technology
and SINTEF Digital, Mathematics & Cybernetics.

This file is part of The Battery Modeling Toolbox BattMo

BattMo is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

BattMo is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with BattMo.  If not, see <http://www.gnu.org/licenses/>.
%}
