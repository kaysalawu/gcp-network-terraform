#!/usr/bin/env python3
import time
import sys
import os
from neo4j import GraphDatabase
from neo4j.debug import watch
from itertools import count
from dotenv import load_dotenv

load_dotenv(".env")

watch("neo4j", out=sys.stdout)
watch("neo4j", out=open("debugLogs.txt", "w"))

uri = os.getenv("NEO4J_URI")
username = os.getenv("NEO4J_USERNAME")
password = os.getenv("NEO4J_PASSWORD")


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


if __name__ == "__main__":
    neo4j_db = Neo4jDatabase(uri, username, password)
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
