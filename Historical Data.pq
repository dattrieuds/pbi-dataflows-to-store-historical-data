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
