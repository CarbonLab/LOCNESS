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