param(
    [string] [Parameter(Mandatory=$true)] $resourceGroup,
    [string] [Parameter(Mandatory=$true)] $searchService,
    [string] [Parameter(Mandatory=$true)] $storageAccount,
    [string] [Parameter(Mandatory=$true)] $functionAppName
  )

  Install-Module -Name Az.Search -Force
  Get-Command -Module Az.Search

  $indexName = $resourceGroup + '-index'
  $skillsetName =  $resourceGroup + '-skills' 
  $indexerName = $resourceGroup + '-indexer'
  $searchSvcApiKey = $(Get-AzSearchAdminKeyPair -ResourceGroupName $resourceGroup -ServiceName $searchService).Primary
  $storageApiKey = $(Get-AzStorageAccountKey -ResourceGroupName $resourceGroup -Name $storageAccount).value[0]
  $headers = @{
    'api-key' = $searchSvcApiKey 
    'Content-Type' = 'application/json' 
    'Accept' = 'application/json' 
  }
  $headers
  $storageApiKey
  $searchSvcApiKey
  
  Write-Host ************************************ Create Index ************************************
  $body = '{
  ''name'': ''' + $indexName + ''',  
  ''fields'': [
      { ''name'': ''id'', ''type'': ''Edm.String'', ''key'': true, ''filterable'': true },
      { ''name'': ''result'',  ''type'': ''Edm.String'', ''searchable'': true, ''filterable'': false, ''sortable'': true,  ''facetable'': false },
      { ''name'': ''content'', ''type'': ''Edm.String'', ''searchable'': true, ''filterable'': false, ''sortable'': false, ''facetable'': false },
      { ''name'': ''text'',    ''type'': ''Edm.String'', ''searchable'': true, ''filterable'': false, ''sortable'': false, ''facetable'': false },
      { ''name'': ''layout'',  ''type'': ''Edm.String'', ''searchable'': false,''filterable'': false, ''sortable'': false, ''facetable'': false },
      { ''name'': ''file'',   ''type'': ''Edm.String'', ''searchable'': false,''filterable'': false, ''sortable'': false, ''facetable'': false }
    ]
  }'
  $body 
  $url = 'https://'+  $searchService  + '.search.windows.net/indexes/' + $indexName + '?api-version=2020-06-30'
  $url
  Invoke-RestMethod -Uri $url -Headers $headers -Method Put -Body $body | ConvertTo-Json
  Write-Host ******************************************************************************************
  Write-Host ************************************ Create Skillset ************************************ 
  $functionKey = Invoke-AzResourceAction -ResourceId ($(Get-AzResourceGroup -Name $resourceGroup).ResourceId + '/providers/Microsoft.Web/sites/{0}/functions/{1}' -f $functionAppName, 'EchoJson') -Action 'listkeys' -ApiVersion '2019-08-01' -Force
  $functionName
  $functionKey
  $body = '{
    ''description'': ''Extract entities, detect language and extract key-phrases'',
    ''skills'':
      [{
        ''@odata.type'': ''#Microsoft.Skills.Vision.OcrSkill'',
        ''description'': ''Extract text (plain and structured) from image.'',
        ''context'': ''/document/normalized_images/*'',
        ''textExtractionAlgorithm'': null,
        ''lineEnding'': ''Space'',
        ''defaultLanguageCode'': ''en'',
        ''detectOrientation'': true,
        ''inputs'': [
          {
            ''name'': ''image'',
            ''source'': ''/document/normalized_images/*''
          }
        ],
        ''outputs'': [
          {
            ''name'': ''text'',
            ''targetName'': ''text''
          },
          {
            ''name'': ''layoutText'',
            ''targetName'': ''layoutText''
          }
        ]
      },
      {
        ''@odata.type'': ''#Microsoft.Skills.Text.MergeSkill'',
        ''description'': ''Create merged_text, which includes all the textual representation of each image inserted at the right location in the content field.'',
        ''context'': ''/document'',
        ''insertPreTag'': '' '',
        ''insertPostTag'': '' '',
        ''inputs'': [
          {
            ''name'': ''text'',
            ''source'': ''/document/content''
          },
          {
            ''name'': ''itemsToInsert'',
            ''source'': ''/document/normalized_images/*/text''
          },
          {
            ''name'': ''offsets'',
            ''source'': ''/document/normalized_images/*/contentOffset''
          }
        ],
        ''outputs'': [
          {
            ''name'': ''mergedText'',
            ''targetName'': ''merged_text''
          }
        ]
      },
      {
        ''@odata.type'': ''#Microsoft.Skills.Text.EntityRecognitionSkill'',
        ''categories'': [ ''Person'', ''Organization'', ''Location'' ],
        ''defaultLanguageCode'': ''en'',
        ''inputs'': [
          { ''name'': ''text'', ''source'': ''/document/content'' }
        ],
        ''outputs'': [
          { ''name'': ''persons'', ''targetName'': ''persons'' },
          { ''name'': ''organizations'', ''targetName'': ''organizations'' },
          { ''name'': ''locations'', ''targetName'': ''locations'' }
        ]
      },
      {
        ''@odata.type'': ''#Microsoft.Skills.Text.LanguageDetectionSkill'',
        ''inputs'': [
          { ''name'': ''text'', ''source'': ''/document/content'' }
        ],
        ''outputs'': [
          { ''name'': ''languageCode'', ''targetName'': ''languageCode'' }
        ]
      },
      {
        ''@odata.type'': ''#Microsoft.Skills.Text.SplitSkill'',
        ''textSplitMode'' : ''pages'',
        ''maximumPageLength'': 4000,
        ''inputs'': [
          { ''name'': ''text'', ''source'': ''/document/content'' },
          { ''name'': ''languageCode'', ''source'': ''/document/languageCode'' }
        ],
        ''outputs'': [
          { ''name'': ''textItems'', ''targetName'': ''pages'' }
        ]
      },
      {
        ''@odata.type'': ''#Microsoft.Skills.Text.KeyPhraseExtractionSkill'',
        ''context'': ''/document/pages/*'',
        ''inputs'': [
          { ''name'': ''text'', ''source'': ''/document/pages/*'' },
          { ''name'':''languageCode'', ''source'': ''/document/languageCode'' }
        ],
        ''outputs'': [
          { ''name'': ''keyPhrases'', ''targetName'': ''keyPhrases'' }
        ]
      },
      {
        ''@odata.type'': ''#Microsoft.Skills.Custom.WebApiSkill'',
        ''description'': ''Custom Skill'',
        ''uri'': ''https://' + $functionAppName + '.azurewebsites.net/api/EchoJson?code=' + ($functionKey).default + ''',
        ''context'': ''/document'',
        ''inputs'': [
          {
            ''name'': ''text'',
            ''source'': ''/document/content''
          },
          {
            ''name'': ''image'',
            ''source'': ''/document/normalized_images/0/data''
          },
          {
            ''name'': ''json'',
            ''source'': ''/document/normalized_images/0/layoutText''
          }
        ],
        ''outputs'': [
          {
            ''name'': ''text'',
            ''targetName'': ''result''
          }
        ]
      }
    ]
  }'
  $body 
  $url = 'https://'+  $searchService  + '.search.windows.net/skillsets/' + $skillsetName + '?api-version=2020-06-30'
  $url
  Invoke-RestMethod -Uri $url -Headers $headers -Method Put -Body $body | ConvertTo-Json
  Write-Host ******************************************************************************************
  Write-Host ************************************ Create Datasource ************************************
  $body = '{
      ''name'' : ''blob-datasource'',
      ''type'' : ''azureblob'',
      ''credentials'' : { ''connectionString'' : ''DefaultEndpointsProtocol=https;AccountName=' + $storageAccount + ';AccountKey=' + $storageApiKey + ';EndpointSuffix=core.windows.net'' },
      ''container'' : { ''name'' : ''blob-datasource''} 
  }'
  $body 
  $url = 'https://'+  $searchService  + '.search.windows.net/datasources?api-version=2020-06-30'
  $url
  Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body | ConvertTo-Json
  Write-Host ******************************************************************************************
  Write-Host ************************************ Create Indexer ************************************
  $body = '{
    ''name'':'''+ $indexerName +''',	
    ''dataSourceName'' : ''blob-datasource'',
    ''targetIndexName'' : ''' + $indexName + ''',
    ''skillsetName'' : '''+ $skillsetName + ''',
    ''fieldMappings'' : [
      {
          ''sourceFieldName'':''metadata_storage_name'',
          ''targetFieldName'' : ''id'',
          ''mappingFunction'': {
            ''name'': ''base64Encode''
          }
      }
    ],
    ''outputFieldMappings'' : [
      {
        ''sourceFieldName'': ''/document/result'',
        ''targetFieldName'': ''result''
      },
      {
        ''sourceFieldName'': ''/document/content'',
        ''targetFieldName'': ''content''
      },
      {
        ''sourceFieldName'': ''/document/normalized_images/0/text'',
        ''targetFieldName'': ''text''
      },
      {
        ''sourceFieldName'': ''/document/normalized_images/0/layoutText'',
        ''targetFieldName'': ''layout''
      },
      {
        ''sourceFieldName'': ''/document/normalized_images/0/data'',
        ''targetFieldName'': ''file''
      }
    ],
    ''parameters'': {
      ''maxFailedItems'' : ''15'', 
      ''batchSize'' : ''100'', 
      ''configuration'': {
      ''dataToExtract'': ''contentAndMetadata'',
      ''parsingMode'':''default'',
      ''allowSkillsetToReadFileData'':true,
      ''imageAction'': ''generateNormalizedImagePerPage''
      }
    }
  }'
  $body 
  $url = 'https://'+  $searchService  + '.search.windows.net/indexers?api-version=2020-06-30'
  $url
  Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body | ConvertTo-Json
  Write-Host ******************************************************************************************