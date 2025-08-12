function items = query_dynamodb_by_date(tableName, start_time, limit, profile, region)
    % QUERY_DYNAMODB_BY_DATE Query DynamoDB using AWS CLI
    %
    %   items = query_dynamodb_by_date('MyTable', '2025-08-01T00:00:00Z', 100, 'myprofile', 'us-west-2')

    if nargin < 5
        region = 'us-west-2'; % default region
    end
    if nargin < 4
        profile = 'default'; % default AWS CLI profile
    end
    if nargin < 3 || isempty(limit)
        limit = 1000;
    end

    % Ensure start_time is in ISO 8601 format
    if ~isempty(start_time)
        if isnumeric(start_time)
            start_time = datetime(start_time, 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z');
        elseif isdatetime(start_time)
            start_time.Format = 'yyyy-MM-dd''T''HH:mm:ss''Z';
        elseif ischar(start_time) || isstring(start_time)
            start_time = char(start_time);
            if ~endsWith(start_time, 'Z')
                start_time = [start_time 'Z'];
            end
        end

        % Build KeyConditionExpression
        keyCondition = sprintf(...
            'static_partition = :pk AND datetime_utc > :dt');

        exprValues = sprintf(...
            '''{":pk":{"S":"data"},":dt":{"S":"%s"}}''', start_time);

    else
        % No date filter
        keyCondition = 'static_partition = :pk';
        exprValues = '''{":pk":{"S":"data"}}''';
    end

    % Build AWS CLI command
    cmd = sprintf(['aws dynamodb query ', ...
        '--table-name "%s" ', ...
        '--key-condition-expression "%s" ', ...
        '--expression-attribute-values %s ', ...
        '--limit %d ', ...
        '--scan-index-forward ', ...
        '--region %s ', ...
        '--profile %s ', ...
        '--output json'], ...
        tableName, keyCondition, exprValues, limit, region, profile);

    % Run command
    [status, cmdout] = system(cmd);

    if status ~= 0
        error('AWS CLI Error:\n%s', cmdout);
    end

    % Parse JSON output
    result = jsondecode(cmdout);

    % Return Items array
    if isfield(result, 'Items')
        items = result.Items;
    else
        items = [];
    end
end
