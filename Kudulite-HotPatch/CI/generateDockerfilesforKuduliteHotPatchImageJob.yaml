parameters:
  ascName: WAWS_Container_Images
  acrName: wawsimages.azurecr.io
  baseImageName: "mcr.microsoft.com/appsvc"
  baseImageVersion: "20220414.2"
  kuduliteInternalRepo: $(KUDU_REPO)
  kuduliteBranch: $(KUDULITE_BRANCH)
  
steps:
- script: |
    if [ "$(InitialChecks)" != "true" ]
    then
      echo "Invalid configuration."
      echo "Variable 'InitialChecks' needs to be 'true' to run this build."
      exit 1
    fi
  displayName: 'Validate pipeline run'

- task: ComponentGovernanceComponentDetection@0

- task: ShellScript@2
  displayName: 'Generate KuduLite Docker Files'
  inputs:
    scriptPath: ./Kudulite-HotPatch/Scripts/generateDockerfilesforKuduliteHotPatchImage.sh
    args: $(Build.ArtifactStagingDirectory) ${{ parameters.baseImageName }} ${{ parameters.baseImageVersion }} ${{ parameters.kuduliteInternalRepo }} $(System.DefaultWorkingDirectory)/Config ${{ parameters.kuduliteBranch }}

- task: PublishBuildArtifacts@1
  inputs:
    pathtoPublish: '$(Build.ArtifactStagingDirectory)'
    artifactName: 'drop'