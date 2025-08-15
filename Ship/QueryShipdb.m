% Example: DynamoDB query using AWS CLI
tableName = 'MyTable';
keyCondition = 'PartitionKey = :pkVal';
pkValue = 'myKey';

cmd = sprintf('aws dynamodb query --table-name "%s" --key-condition-expression "%s" --expression-attribute-values ''{"":pkVal":{"S":"%s"}}''', ...
              tableName, keyCondition, pkValue);

[status, cmdout] = system(cmd);

if status ~= 0
    error('AWS CLI error: %s', cmdout);
end

% Parse JSON result
result = jsondecode(cmdout);
disp(result.Items)
%%
[status, cmdout] = system('aws dynamodb list-tables --profile RVCONNDB');
result = jsondecode(cmdout);
disp(result)
%%
[status, cmdout] = system('aws dynamodb list-tables --profile RVCONNDB');
result = jsondecode(cmdout);
disp(result)
%%
[status, cmdout] = system('aws dynamodb describe-table --table-name locness-underway-summary --output json --profile RVCONNDB');
if status ~= 0
    error("Describe table failed: %s", cmdout);
end
tableInfo = jsondecode(cmdout);
disp(tableInfo.Table.KeySchema)


%%
disp({tableInfo.Table.KeySchema.AttributeName})
disp({tableInfo.Table.KeySchema.KeyType})
%% THIS WORKS
command = 'aws dynamodb query --table-name locness-underway-summary --key-condition-expression "static_partition = :pk" --expression-attribute-values "{\":pk\":{\"S\":\"data\"}}" --limit 10 --region us-east-1 --output json --profile RVCONNDB';
[status, output] = system(command);
result = jsondecode(output);
%% THIS WORKS
table_name = 'locness-underway-summary';
key_condition = '"static_partition = :pk"';
attr_values = '"{\":pk\":{\"S\":\"data\"}}"';
limit = '10';
region = 'us-east-1';
profile = 'RVCONNDB';

command = sprintf('aws dynamodb query --table-name %s --key-condition-expression %s --expression-attribute-values %s --limit %s --region %s --output json --profile %s', ...
    table_name, key_condition, attr_values, limit, region, profile);
[status, output] = system(command);
result = jsondecode(output);
%% add date filter
tic;
table_name = 'locness-underway-summary';
% Single query for the day
end_time = datetime('now', 'Format', 'uuuu-MM-dd''T''HH:mm:ss''Z''', 'TimeZone', 'UTC');
start_time = end_time - seconds(60);
key_condition = '"static_partition = :pk AND datetime_utc BETWEEN :start_dt AND :end_dt"';
attr_values = ['"{\":pk\":{\"S\":\"data\"},\":start_dt\":{\"S\":\"', char(start_time), '\"},\":end_dt\":{\"S\":\"', char(end_time), '\"}}"'];
limit = '1800';
region = 'us-east-1';
profile = 'RVCONNDB';
command = sprintf('aws dynamodb query --table-name %s --key-condition-expression %s --expression-attribute-values %s --limit %s --region %s --output json --profile %s', ...
    table_name, key_condition, attr_values, limit, region, profile);
[status, output] = system(command);
result = jsondecode(output);
% Use the function
data_table = dynamodb_to_table(result.Items);
% disp(data_table);
toc
%%
% key_condition = '"static_partition = :pk AND datetime_utc >= :start_dt"';
% attr_values = '"{\":pk\":{\"S\":\"data\"},\":start_dt\":{\"S\":\"2025-08-11T00:00:00Z\"}}"';
%% Return the last record
table_name = 'locness-underway-summary';
key_condition = '"static_partition = :pk"';
attr_values = '"{\":pk\":{\"S\":\"data\"}}"';
region = 'us-east-1';
profile = 'RVCONNDB';

% Scan descending order and return only 1 item
limit = '1';
scan_forward = '--scan-index-forward false';

command = sprintf(['aws dynamodb query --table-name %s ', ...
    '--key-condition-expression %s ', ...
    '--expression-attribute-values %s ', ...
    '--limit %s %s ', ...
    '--region %s --output json --profile %s'], ...
    table_name, key_condition, attr_values, limit, scan_forward, region, profile);

[status, output] = system(command);
result = jsondecode(output);
%% Test handler function
tic
handler = ShipDataHandler();
handler.AppendCurrentLocation();
handler.copyToGliderviz();
toc
%%
% Generic function to convert DynamoDB items to table
function data_table = dynamodb_to_table(items)
    if isempty(items)
        data_table = table();
        return;
    end
    
    numItems = length(items);
    
    % Get all field names from the first item
    firstItem = items{1};
    fieldNames = fieldnames(firstItem);
    
    % Initialize data structure
    data = struct();
    
    for i = 1:length(fieldNames)
        fieldName = fieldNames{i};
        firstField = firstItem.(fieldName);
        
        if isfield(firstField, 'S')  % String type
            data.(fieldName) = cell(numItems, 1);
        elseif isfield(firstField, 'N')  % Number type
            data.(fieldName) = zeros(numItems, 1);
        elseif isfield(firstField, 'BOOL')  % Boolean type
            data.(fieldName) = false(numItems, 1);
        else
            data.(fieldName) = cell(numItems, 1);  % Default to cell array
        end
    end
    
    % Fill in the data
    for i = 1:numItems
        item = items{i};
        for j = 1:length(fieldNames)
            fieldName = fieldNames{j};
            if isfield(item, fieldName)
                field = item.(fieldName);
                if isfield(field, 'S')
                    data.(fieldName){i} = field.S;
                elseif isfield(field, 'N')
                    data.(fieldName)(i) = str2double(field.N);
                elseif isfield(field, 'BOOL')
                    data.(fieldName)(i) = field.BOOL;
                end
            end
        end
    end
    
    % Convert to table
    data_table = struct2table(data);
    
    % Convert datetime fields if they exist
    if ismember('datetime_utc', data_table.Properties.VariableNames)
        data_table.datetime_utc = datetime(data_table.datetime_utc, ...
            'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'TimeZone', 'UTC');
    end
end
