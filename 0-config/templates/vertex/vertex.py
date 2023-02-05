from google.cloud import aiplatform

job = aiplatform.PipelineJob(display_name = DISPLAY_NAME,
                             template_path = html_pipeline.json,
                             job_id = JOB_ID,
                             pipeline_root = PIPELINE_ROOT_PATH,
                             parameter_values = PIPELINE_PARAMETERS,
                             enable_caching = ENABLE_CACHING,
                             encryption_spec_key_name = CMEK,
                             labels = LABELS,
                             credentials = CREDENTIALS,
                             project = PROJECT_ID,
                             location = LOCATION)

job.submit(service_account=SERVICE_ACCOUNT,
           network=NETWORK)
