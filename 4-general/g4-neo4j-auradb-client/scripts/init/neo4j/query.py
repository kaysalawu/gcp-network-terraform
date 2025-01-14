#!/usr/bin/env python3

import time
import sys
from neo4j import GraphDatabase
from neo4j.debug import watch
from itertools import count

watch("neo4j", out=sys.stdout)
watch("neo4j", out=open("debugLogs.txt", "w"))

# Neo4j connection details
uri = "neo4j+s://73cca245-duvalall5.databases.neo4j-dev.io"
username = "neo4j"  # Replace with your Neo4j username
password = (
    "86IGaj_JyG2Szezy4ZFetna0xO5WkwInuLES8rWt8mU"  # Replace with your Neo4j password
)


def read_name_value_file(filename):
    # Dictionary to store the name=value pairs
    name_value_dict = {}

    # Open the file for reading
    with open(filename, "r") as file:
        for line in file:
            # Strip whitespace and newline characters
            line = line.strip()

            # Skip empty lines or lines without an '=' character
            if "=" not in line or not line:
                continue

            # Split the line into name and value
            name, value = line.split("=", 1)

            # Strip any extra spaces around name and value
            name = name.strip()
            value = value.strip()

            # Add the name and value to the dictionary
            name_value_dict[name] = value

    return name_value_dict


class Neo4jDatabase:

    def __init__(self, uri, username, password):
        self.driver = GraphDatabase.driver(
            uri, auth=(username, password), liveness_check_timeout=180
        )  # keep_alive=True, max_connection_lifetime=180)

    def close(self):
        self.driver.close()

    def query(self, cypher_query):
        with self.driver.session() as session:
            result = session.run(cypher_query)
            return [record.data() for record in result]


# Example usage
if __name__ == "__main__":

    if len(sys.argv) != 2:
        print("Usage: python script.py <filename>")
        sys.exit(1)
    # Get the filename from the command-line argument
    filename = sys.argv[1]
    # Read and process the file
    config = read_name_value_file(filename)
    # Connect to the database
    neo4j_db = Neo4jDatabase(
        config["NEO4J_URI"], config["NEO4J_USERNAME"], config["NEO4J_PASSWORD"]
    )

    for i in count(0):
        print("*" * 80)
        print(f"Connection {i}")
        print("*" * 80)
        # Write your Cypher query
        cypher_query = """
        SHOW DATABASES
        """
        # Run the query and print the results
        results = neo4j_db.query(cypher_query)
        for record in results:
            print(record)
        time.sleep(2)

    # Close the connection
    neo4j_db.close()
