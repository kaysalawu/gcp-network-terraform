from main import OrchestraStateMachine

graph_output_name = "state_diagram"
test_orchestra = OrchestraStateMachine("test-orchestra", "test-cluster", "test-project")
test_orchestra.generate_state_diagram(graph_output_name)
print(f"State diagram generated: {graph_output_name}.png")
