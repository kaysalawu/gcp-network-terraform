import requests
import logging
from google.cloud import dns

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_current_project_id():
    metadata_url = "http://169.254.169.254/computeMetadata/v1/project/project-id"
    headers = {"Metadata-Flavor": "Google"}
    response = requests.get(metadata_url, headers=headers)
    response.raise_for_status()
    return response.text


def get_dns_zone(project_id, search_string):
    client = dns.Client(project=project_id)
    zones = client.list_zones()

    filtered_zones = []
    for zone in zones:
        if search_string.lower() in zone.name.lower():
            zone_info = {
                "name": zone.name,
                "dns_name": zone.dns_name,
                "description": zone.description,
            }
            filtered_zones.append(zone_info)

    return filtered_zones


def create_dns_a_record(
    state, project_id, private_dns_zone, orchestra_name, pod_name, pod_ip
):
    if not private_dns_zone:
        logger.error("[create_dns_a_record] No private DNS zone found.")
        return

    zone_name = private_dns_zone[0]["name"]
    dns_name = private_dns_zone[0]["dns_name"]
    record_name = f"{pod_name}-{orchestra_name}.{dns_name}"

    client = dns.Client(project=project_id)
    zone = client.zone(zone_name)

    # Fetch existing records
    existing_records = list(zone.list_resource_record_sets())
    for record in existing_records:
        if record.name == record_name and record.record_type == "A":
            return

    # Create new record if it doesn't exist
    record_set = zone.resource_record_set(
        name=record_name, record_type="A", ttl=300, rrdatas=[pod_ip]
    )
    changes = zone.changes()
    changes.add_record_set(record_set)
    changes.create()

    logger.info(
        f"[{orchestra_name}] {state} -> create_dns_a_record() -> Added {record_name} = {pod_ip}"
    )


def delete_dns_a_record(
    state, project_id, private_dns_zone, orchestra_name, pod_name, pod_ip
):
    if not private_dns_zone:
        logger.error()
        return

    zone_name = private_dns_zone[0]["name"]
    dns_name = private_dns_zone[0]["dns_name"]
    record_name = f"{pod_name}-{orchestra_name}.{dns_name}"

    client = dns.Client(project=project_id)
    zone = client.zone(zone_name)

    for record in zone.list_resource_record_sets():
        if record.record_type == "A" and record.name == record_name:
            changes = zone.changes()
            changes.delete_record_set(record)
            changes.create()
            logger.info(
                f"[{orchestra_name}] {state} -> delete_dns_a_record() -> Deleted {record.name} = {record.rrdatas}"
            )
            return


def get_existing_dns_a_records(state, project_id, private_dns_zone, orchestra_name):
    if not private_dns_zone:
        logger.error(
            f"[{orchestra_name}] {state} -> get_existing_dns_a_records: No zone supplied!"
        )
        return []

    zone_name = private_dns_zone[0]["name"]
    client = dns.Client(project=project_id)
    zone = client.zone(zone_name)

    existing_records = []
    for record in zone.list_resource_record_sets():
        if record.record_type == "A" and orchestra_name in record.name:
            existing_records.append({"name": record.name, "rrdatas": record.rrdatas})

    return existing_records
