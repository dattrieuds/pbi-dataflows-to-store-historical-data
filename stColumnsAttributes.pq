//We do not nest this table inside the fnRenameColumns function to avoid the error "Formula.Firewall: Query X references other queries or steps, so it may not directly access a data source. Please rebuild this data combination.". 
  //So for a workaround, we have to have it as an explicit table.
let
  Source = AzureStorage.DataLake(prADLSFolderPath & "model.json.snapshots/"), 
  #"Sort latest Date modified first" = Table.Sort(Source, {{"Date modified", Order.Descending}}), 
  #"Filter only the fist file after sorting" = #"Sort latest Date modified first"{0}[Content], 
  #"Imported JSON" = Json.Document(#"Filter only the fist file after sorting", 1252), 
  #"List of Dataflow tables" = #"Imported JSON"[entities], 
  #"Converted to Table" = Table.FromList(
    #"List of Dataflow tables", 
    Splitter.SplitByNothing(), 
    null, 
    null, 
    ExtraValues.Error
  ), 
  // Attributes column now has rows of Lists.
  #"Expand only Source and Attributes" = Table.ExpandRecordColumn(
    #"Converted to Table", 
    "Column1", 
    {"name", "attributes"}, 
    {"Source", "Attributes"}
  ), 
  // Attributes column now has rows of Records.
  #"Expand Attributes list" = Table.ExpandListColumn(
    #"Expand only Source and Attributes", 
    "Attributes"
  ), 
  #"Expand to ColumnName and dataType" = Table.ExpandRecordColumn(
    #"Expand Attributes list", 
    "Attributes", 
    {"name", "dataType"}, 
    {"ColumnName", "dataType"}
  ), 
  // This step is added to get Index later per Source. Ref: https://www.youtube.com/watch?v=7CqXdSEN2k4
  #"Grouped Rows" = Table.Group(
    #"Expand to ColumnName and dataType", 
    {"Source"}, 
    {
      {
        "Data", 
        each _, 
        type table [Source = nullable text, ColumnName = nullable text, dataType = nullable text]
      }
    }
  ), 
  // Data with new Index column now has rows of Tables.
  #"Add Data with new Index" = Table.AddColumn(
    #"Grouped Rows", 
    "Data with new Index", 
    each Table.AddIndexColumn([Data], "Index", 1)
  ), 
  // Just to make data cleaner.
  #"Choose only Data with new Index column" = Table.SelectColumns(
    #"Add Data with new Index", 
    {"Data with new Index"}
  ), 
  #"Expand Data with new Index" = Table.ExpandTableColumn(
    #"Choose only Data with new Index column", 
    "Data with new Index", 
    {"Source", "ColumnName", "dataType", "Index"}, 
    {"Source", "ColumnName", "dataType", "Index"}
  ), 
  #"Add FieldKey" = Table.AddColumn(
    #"Expand Data with new Index", 
    "FieldKey", 
    each Text.Combine({"Column", Text.From([Index], "en-US")}), 
    type text
  ), 
  // This step is needed later on to dynamically define the Column type based on the model.json from Dataflow. Refer to columns M and Dataflow JSON in https://app.powerbi.com/view?r=eyJrIjoiZDRhNmY4MWUtMmUzYS00YjI5LWExY2MtODZlYTE4M2NhYWVjIiwidCI6IjBmNjIxYzY3LTk4YTAtNGVkNS1iNWJkLTMxYTM1YmU0MWUyOSIsImMiOjh9
  #"Add ColumnType" = Table.AddColumn(
    #"Add FieldKey", 
    "ColumnType", 
    each 
      if [dataType] = "string" then
        type text
      else if [dataType] = "int64" then
        Int64.Type
      else if [dataType] = "double" then
        type number
      else if [dataType] = "date" then
        type date
      else if [dataType] = "dateTime" then
        type datetime
      else if [dataType] = "dateTimeOffset" then
        type datetimezone
      else if [dataType] = "time" then
        type time
      else if [dataType] = "boolean" then
        type logical
      else if [dataType] = "decimal" then
        Currency.Type
      else
        type any
    
  ),
    #"Change column types" = Table.TransformColumnTypes(
    #"Add ColumnType", 
    {{"Source", type text}, {"ColumnName", type text}, {"dataType", type text}}
  ), 
  #"Choose neccessary columns" = Table.SelectColumns(
    #"Change column types", 
    {"Source", "FieldKey", "ColumnName", "ColumnType"}
  )
in
  #"Choose neccessary columns"
