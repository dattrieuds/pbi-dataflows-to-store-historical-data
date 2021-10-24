// Current Data
let
    Source = PowerBI.Dataflows(null),
    NavToWorkspace = Source{[workspaceId= prWorkspaceId]}[Data],
    NavtoDataflow = NavToWorkspace{[dataflowId= prDataflowId]}[Data],
    NavToEntity = NavtoDataflow{[entity= prEntityNameCurrent]}[Data]
in
    NavToEntity

// prWorkspaceId
"yourWorkspaceId" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]

// prDataflowId
"yourDataflowId" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]

// prEntityNameCurrent
"yourEntityNameCurrent" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]

// prADLSFolderPath
"https://yourADLSStorageAccountGen2.dfs.core.windows.net/powerbi/yourPBIWorkspaceName/yourPBIDataflowsName/" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]

// prEntityNameHistorical
"yourEntityNameHistorical" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]

// Historical Data
let
  Source = 
    let
      // This step is nested to be reused later on.                                             
      Selectedfolder = 
        let
          Source = AzureStorage.DataLake(prADLSFolderPath & prEntityNameHistorical & ".csv.snapshots/"), 
          #"Removed Other Columns" = Table.SelectColumns(Source, {"Date modified", "Content"})
        in
          #"Removed Other Columns", 
      Source = Selectedfolder, 
      #"Choose Date modified column only" = Table.SelectColumns(Source, {"Date modified"}), 
      #"Add Date column" = Table.AddColumn(
        #"Choose Date modified column only", 
        "Date", 
        each Text.Combine(
          {
            DateTime.ToText([Date modified], "yyyy"), 
            "-", 
            DateTime.ToText([Date modified], "MM"), 
            "-", 
            DateTime.ToText([Date modified], "dd")
          }
        ), 
        type text
      ), 
      #"Change Date column type" = Table.TransformColumnTypes(
        #"Add Date column", 
        {{"Date", type date}}
      ), 
      #"Take only latest file for each date" = Table.Group(
        #"Change Date column type", 
        {"Date"}, 
        {{"MaxTime", each List.Max([Date modified]), type nullable datetime}}
      ), 
      #"Inner join with Selectedfolder" = Table.NestedJoin(
        #"Take only latest file for each date", 
        {"MaxTime"}, 
        Selectedfolder, 
        {"Date modified"}, 
        "Selectedfolder", 
        JoinKind.Inner
      ), 
      #"Add Content columns" = Table.ExpandTableColumn(
        #"Inner join with Selectedfolder", 
        "Selectedfolder", 
        {"Content"}, 
        {"Content"}
      )
    in
      #"Add Content columns", 
  #"Invoke Transform File Function" = Table.AddColumn(
    Source, 
    "fnRenameColumns", 
    each fnRenameColumns([Content], prADLSFolderPath, prEntityNameHistorical)
  ), 
  #"Choose necessary columns" = Table.SelectColumns(
    #"Invoke Transform File Function", 
    {"Date", "fnRenameColumns"}
  ), 
  // Take the column names of the last table by using List.Last. It's logic, since we use the last model.json file to extract column names and column types.                                                                                                                                                          
  #"Expand appended table" = Table.ExpandTableColumn(
    #"Choose necessary columns", 
    "fnRenameColumns", 
    Table.ColumnNames(List.Last(#"Choose necessary columns"[fnRenameColumns]))
  ), 
  // This steps contains several nested steps. Final result gives a list of list (list of ColumnName and ColumnType).                                                                                                                     
  // We don't nest this step in the fnRenameColumns function since after appending many tables together, the column types become Any. So it's good to do this step after "appending table" step.                                                                                                                                                                                         
  #"Change column types dynamically" = Table.TransformColumnTypes(
    #"Expand appended table", 
    Table.ToRows(
      Table.SelectColumns(
        Table.SelectRows(stColumnsAttributes, each [Source] = prEntityNameHistorical), 
        {"ColumnName", "ColumnType"}
      )
    )
  )
in
  #"Change column types dynamically"

// stColumnsAttributes
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

// fnRenameColumns
(ContentTable as binary, ADLSFolderPath as text, TableToTransform as text) =>
  let
    Source = Csv.Document(
      ContentTable,
      [Delimiter = ",", Encoding = 1252, QuoteStyle = CsvStyle.QuoteAlways]
    ),
    // This steps contains several nested steps. Final result gives a list of list (list of oldColumnName and newColumnName).                                                                                                                         
    #"Change column names dynamically" = Table.RenameColumns(
      Source,
      Table.ToRows(
        Table.SelectColumns(
          Table.SelectRows(stColumnsAttributes, each [Source] = TableToTransform),
          {"FieldKey", "ColumnName"}
        )
      )
    )
  in
    #"Change column names dynamically"
