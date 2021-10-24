let
    Source = PowerBI.Dataflows(null),
    NavToWorkspace = Source{[workspaceId="yourWorkspaceId"]}[Data],
    NavtoDataflow = NavToWorkspace{[dataflowId="yourDataflowId"]}[Data],
    NavToTable = NavtoDataflow{[entity="yourTableName"]}[Data]
in
    NavToTable
