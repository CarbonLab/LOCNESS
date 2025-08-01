function [lat_predict, lon_predict] = ntxwpt(t,glider);
% input: 
% 't' (engineering struct)
% glider: 1 or 2 (Spray1 or Spray2)
    
% output:
% predicted latitude
% predicted longitude

if glider == 2

% find current waypoint
swp = [t.eng.n0.wlat(end) t.eng.n0.wlon(end)] ; % waypoint for last dive
dx = t.gps.lon.diveend(end) - t.gps.lon.divestart(end) ;
dy = t.gps.lat.diveend(end) - t.gps.lat.divestart(end) ;

% predict next lon/lat by just adding dlat or dlon to the last surfacing
    lat_predict = t.gps.lat.diveend(end) + dy ;
    lon_predict = t.gps.lon.diveend(end) + dx; 
    
    % flag to see if surfacing is within 2 km of current WP. 
    [distwp1] = deg2km(distance(t.gps.lat.diveend(end), t.gps.lon.diveend(end), swp(1), swp(2)));
    
    % if it is within 1 km from WP, then take waypoint from master list
    if(distwp1<1)
        allWpts = t.eng.wpt.list(2).pts;        
        idx = find(ismember(allWpts, swp, 'rows'));
        
        % assume its going to the next waypoint
            if ~isempty(idx) && idx < size(allWpts,1)
                newWpt = allWpts(idx + 1, :)
            elseif isempty(idx)
                disp('Target waypoint not found.');
            else
                disp('Target is the last waypoint — no next waypoint.');
            end

        % project original distance over ground in direction of new
        % waypoint
        % Compute distance moved
        d = hypot(dy, dx);

            % Current position
            pos = [t.gps.lat.diveend(end), t.gps.lon.diveend(end)];       % [lat, lon]

        % Compute direction vector toward waypoint 2
        delta = newWpt - pos;
        unitVec = delta / norm(delta);

        % Project the same distance along the new direction
        dx2 = d * unitVec(1);
        dy2 = d * unitVec(2);

        % Predict next position
        [predictedPos] = pos + [dx2, dy2];
        lat_predict = predictedPos(1); lon_predict = predictedPos(2) ;
    end

elseif glider == 1
swp = [t.eng.en.wlat(end) t.eng.en.wlon(end)] ; % waypoint for last dive
dx = t.lon(end,2) - t.lon(end,1) ;
dy = t.lat(end,2) - t.lat(end,1) ;

% predict next lon/lat by just adding dlat or dlon to the last surfacing
    lat_predict = t.lat(end,2) + dy ;
    lon_predict = t.lon(end,2) + dx; 
    
    % flag to see if surfacing is within 2 km of current WP. 
    [distwp1] = deg2km(distance(t.lat(end,2), t.lon(end,2), swp(1), swp(2)));
    
    % if it is within 1 km from WP, then take waypoint from master list
    if(distwp1<1)
        % ++++ may break here if index moves +++++
        d = ~isempty(t.eng.wpt.index)
        nonempty_idx = find(~cellfun('isempty', t.eng.wpt.index));
        allWpts = [t.eng.wpt.lat(nonempty_idx) t.eng.wpt.lon(nonempty_idx)]; 
        allWpts = [allWpts{:}];;  

        idx = find(ismember(allWpts, swp, 'rows'));
        
        % assume its going to the next waypoint
            if ~isempty(idx) && idx < size(allWpts,1)
                newWpt = allWpts(idx + 1, :)
            elseif isempty(idx)
                disp('Target waypoint not found.');
            else
                disp('Target is the last waypoint — no next waypoint.');
            end

        % project original distance over ground in direction of new
        % waypoint
        % Compute distance moved
        d = hypot(dy, dx);

            % Current position
            pos = [t.lat(end,2), t.lon(end,2)];       % [lat, lon]

        % Compute direction vector toward waypoint 2
        delta = newWpt - pos;
        unitVec = delta / norm(delta);

        % Project the same distance along the new direction
        dx2 = d * unitVec(1);
        dy2 = d * unitVec(2);

        % Predict next position
        [predictedPos] = pos + [dx2, dy2];
        lat_predict = predictedPos(1); lon_predict = predictedPos(2) ;
    end
end
end