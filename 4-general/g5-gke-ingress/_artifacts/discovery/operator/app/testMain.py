import unittest
from main import OrchestraStateMachine


class TestOrchestraStateMachine(unittest.TestCase):
    def setUp(self):
        self.orchestra1_pods = [
            {
                "podName": "pod1",
                "podIp": "10.1.1.1",
                "hostIp": "10.2.1.1",
                "phase": "Running",
            },
            {
                "podName": "pod2",
                "podIp": "10.1.1.2",
                "hostIp": "10.2.1.2",
                "phase": "Running",
            },
        ]
        self.orchestra2_pods = [
            {
                "podName": "pod3",
                "podIp": "10.3.1.1",
                "hostIp": "10.4.1.1",
                "phase": "Running",
            },
            {
                "podName": "pod4",
                "podIp": "10.3.1.2",
                "hostIp": "10.4.1.2",
                "phase": "Running",
            },
        ]

        self.orchestra1 = OrchestraStateMachine("test-orchestra1", self.orchestra1_pods)
        self.orchestra2 = OrchestraStateMachine("test-orchestra2", self.orchestra2_pods)

    def test_transitions_orchestra1(self):
        self.orchestra1.scan_pods()
        self.assertEqual(self.orchestra1.state, "updating_cr")

        self.orchestra1.update_custom_resource()
        self.assertEqual(self.orchestra1.state, "reconciling_dns")

        self.orchestra1.reconcile_dns()
        self.assertEqual(self.orchestra1.state, "completed")

    def test_transitions_orchestra2(self):
        self.orchestra2.scan_pods()
        self.assertEqual(self.orchestra2.state, "updating_cr")

        self.orchestra2.update_custom_resource()
        self.assertEqual(self.orchestra2.state, "reconciling_dns")

        self.orchestra2.reconcile_dns()
        self.assertEqual(self.orchestra2.state, "completed")

    def test_delete_flow(self):
        self.orchestra1.delete_dns_records()
        self.assertEqual(self.orchestra1.state, "completed")


if __name__ == "__main__":
    unittest.main()
