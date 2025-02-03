import logging
import time
from transitions import Machine

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)


class OrchestraStateMachine:
    states = [
        "idle",
        "scanning",
        "updating_cr",
        "reconciling_dns",
        "deleting_dns",
        "completed",
        "error",
    ]

    def __init__(self, orchestra_name):
        self.orchestra_name = orchestra_name
        self.pod_info = []

        self.machine = Machine(
            model=self,
            states=OrchestraStateMachine.states,
            initial="idle",
            transitions=[
                {
                    "trigger": "start_scan",
                    "source": "idle",
                    "dest": "scanning",
                    "after": "scan_pods",
                },
                {
                    "trigger": "finish_scan",
                    "source": "scanning",
                    "dest": "updating_cr",
                    "after": "update_custom_resource",
                },
                {
                    "trigger": "update_cr",
                    "source": "updating_cr",
                    "dest": "reconciling_dns",
                    "after": "reconcile_dns",
                },
                {
                    "trigger": "finish_reconcile",
                    "source": "reconciling_dns",
                    "dest": "completed",
                },
                {
                    "trigger": "start_delete",
                    "source": "idle",
                    "dest": "deleting_dns",
                    "after": "delete_dns_records",
                },
                {
                    "trigger": "finish_delete",
                    "source": "deleting_dns",
                    "dest": "completed",
                },
                {"trigger": "error_occurred", "source": "*", "dest": "error"},
            ],
        )

    def scan_pods(self):
        logger.info(f"[{self.orchestra_name}] State: {self.state} -> Scanning pods")
        time.sleep(1)
        self.pod_info = [
            {"name": "pod1", "ip": "10.1.1.1"},
            {"name": "pod2", "ip": "10.1.1.2"},
        ]
        self.finish_scan()

    def update_custom_resource(self):
        logger.info(f"[{self.orchestra_name}] State: {self.state} -> Updating CR")
        time.sleep(1)
        logger.info(f"[{self.orchestra_name}] Updated CR with pods: {self.pod_info}")
        self.update_cr()

    def reconcile_dns(self):
        logger.info(f"[{self.orchestra_name}] State: {self.state} -> Reconciling DNS")
        time.sleep(1)
        logger.info(f"[{self.orchestra_name}] DNS reconciliation complete")
        self.finish_reconcile()

    def delete_dns_records(self):
        logger.info(
            f"[{self.orchestra_name}] State: {self.state} -> Deleting DNS records"
        )
        time.sleep(1)
        logger.info(f"[{self.orchestra_name}] DNS records deleted")
        self.finish_delete()


def process_orchestra(orchestra_name):
    orchestra = OrchestraStateMachine(orchestra_name)
    orchestra.start_scan()
