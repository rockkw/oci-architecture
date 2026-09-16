import io
import json

import oci
from fdk import response


def handler(ctx, data: io.BytesIO = None):
    body = json.loads(data.getvalue())
    result = process_uploaded_object(body)
    return response.Response(
        ctx,
        response_data=json.dumps(result),
        headers={"Content-Type": "application/json"},
    )


def process_uploaded_object(event_body):
    signer = oci.auth.signers.get_resource_principals_signer()

    resource_name = event_body.get("data", {}).get("resourceName")
    namespace = event_body.get("data", {}).get("additionalDetails", {}).get("namespace")
    bucket_name = event_body.get("data", {}).get("additionalDetails", {}).get("bucketName")

    if not all([resource_name, namespace, bucket_name]):
        return {"error": "event payload missing bucket/namespace/object details"}

    ai_client = oci.ai_document.AIServiceDocumentClient({}, signer=signer)

    input_location = oci.ai_document.models.ObjectStorageLocations(
        source_type="OBJECT_STORAGE_LOCATIONS",
        object_locations=[
            oci.ai_document.models.ObjectLocation(
                namespace_name=namespace,
                bucket_name=bucket_name,
                object_name=resource_name,
            )
        ]
    )

    output_location = oci.ai_document.models.OutputLocation(
        namespace_name=namespace,
        bucket_name=bucket_name.replace("lab-docs-input", "lab-docs-output"),
        prefix=f"results/{resource_name}",
    )

    processor_config = oci.ai_document.models.GeneralProcessorConfig(
        processor_type="GENERAL",
        features=[
            oci.ai_document.models.DocumentTextExtractionFeature(
                feature_type="TEXT_EXTRACTION",
                generate_searchable_pdf=False,
            )
        ],
    )

    create_job_details = oci.ai_document.models.CreateProcessorJobDetails(
        compartment_id=signer.compartment_id,
        display_name=f"ocr-{resource_name}",
        input_location=input_location,
        output_location=output_location,
        processor_config=processor_config,
    )

    try:
        job = ai_client.create_processor_job(create_processor_job_details=create_job_details)
        return {
            "status": "submitted",
            "job_id": job.data.id,
            "object": resource_name,
            "output_prefix": output_location.prefix,
        }
    except Exception as e:
        return {"status": "error", "object": resource_name, "error": str(e)}
