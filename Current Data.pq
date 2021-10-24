let
    Source = PowerBI.Dataflows(null),
    NavToWorkspace = Source{[workspaceId= prWorkspaceId]}[Data],
    NavtoDataflow = NavToWorkspace{[dataflowId= prDataflowId]}[Data],
    NavToEntity = NavtoDataflow{[entity= prEntityNameCurrent]}[Data]
in
    NavToEntity
