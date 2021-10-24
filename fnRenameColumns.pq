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
