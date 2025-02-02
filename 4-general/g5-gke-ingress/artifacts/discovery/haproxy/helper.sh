#!/bin/bash

if [ $# -eq 0 ]; then
    echo -e "\nUsage: $0 ["
    echo "  --substitute|-s"
    echo "  --substitute-one|-o"
    exit 1
fi

helm_chart_name="neo4j-native"
base_dir="charts"
templates_dirs=(
"$base_dir/0-system"
"$base_dir/1-apps"
"$base_dir/2-haproxy"
"$base_dir/3-k6"
)

substitute_separate_templates() {
    for templates_dir in "${templates_dirs[@]}"; do
        output_dir="${base_dir}_rendered/$(basename "$templates_dir")/templates"
        mkdir -p "$output_dir"
        for template in "$templates_dir/templates"/*.yaml; do
            output_file="$output_dir/$(basename "$template")"
            helm template "$(basename "$templates_dir")" "$templates_dir" -f "$base_dir/values.yaml" --show-only "templates/$(basename "$template")" >"$output_file"
        done
    done
}

substitue_into_one_template() {
    for templates_dir in "${templates_dirs[@]}"; do
        output_file="${base_dir}_rendered/$(basename "$templates_dir")/templates/combined.yaml"
        mkdir -p "${base_dir}_rendered/$(basename "$templates_dir")/templates"
        helm template "$(basename "$templates_dir")" "$templates_dir" -f "$base_dir/values.yaml" >"$output_file"
    done
}

case $1 in
"--substitute" | "-s")
    substitute_separate_templates
    ;;
"--substitute-one" | "-o")
    substitue_into_one_template
    ;;
*)
    echo -e "\nUsage: $0 ["
    echo "  --substitute|-s"
    echo "  --substitute-one|-o"
    exit 1
    ;;
esac
