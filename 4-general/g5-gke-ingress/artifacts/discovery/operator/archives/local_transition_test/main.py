import logging
from transitions import Machine

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
logging.getLogger("transitions.core").setLevel(logging.WARNING)


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

    def __init__(self, orchestra_name, pod_info=None):
        self.orchestra_name = orchestra_name
        self.pod_info = pod_info or []

        self.machine = Machine(
            model=self,
            states=OrchestraStateMachine.states,
            initial="idle",
            transitions=[
                {"trigger": "start_scan", "source": "idle", "dest": "scanning"},
                {"trigger": "finish_scan", "source": "scanning", "dest": "updating_cr"},
                {
                    "trigger": "update_cr",
                    "source": "updating_cr",
                    "dest": "reconciling_dns",
                },
                {
                    "trigger": "finish_reconcile",
                    "source": "reconciling_dns",
                    "dest": "completed",
                },
                {"trigger": "start_delete", "source": "idle", "dest": "deleting_dns"},
                {
                    "trigger": "finish_delete",
                    "source": "deleting_dns",
                    "dest": "completed",
                },
                {"trigger": "error_occurred", "source": "*", "dest": "error"},
            ],
        )

    def scan_pods(self):
        self.start_scan()
        logger.info(f"[{self.orchestra_name}] State: {self.state} -> Scanning pods")
        logger.info(f"[{self.orchestra_name}] Pods found: {len(self.pod_info)}")
        self.finish_scan()

    def update_custom_resource(self):
        logger.info(f"[{self.orchestra_name}] State: {self.state} -> Updating CR")
        logger.info(f"[{self.orchestra_name}] Updated CR with pods: {self.pod_info}")
        self.update_cr()

    def reconcile_dns(self):
        logger.info(f"[{self.orchestra_name}] State: {self.state} -> Reconciling DNS")
        logger.info(f"[{self.orchestra_name}] DNS reconciliation complete")
        self.finish_reconcile()

    def delete_dns_records(self):
        self.start_delete()
        logger.info(
            f"[{self.orchestra_name}] State: {self.state} -> Deleting DNS records"
        )
        logger.info(f"[{self.orchestra_name}] DNS records deleted")
        self.finish_delete()
