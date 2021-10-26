let
    Source = PowerBI.Dataflows(null),
    NavToWorkspace = Source{[workspaceName= prWorkspaceName]}[Data],
    NavtoDataflow = NavToWorkspace{[dataflowName= prDataflowName]}[Data],
    NavToEntity = NavtoDataflow{[entity= prEntityNameCurrent]}[Data]
in
    NavToEntity
