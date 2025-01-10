#!/usr/bin/env python3
import time
import sys
from neo4j import GraphDatabase
from neo4j.debug import watch
from itertools import count
watch("neo4j", out=sys.stdout)
watch("neo4j", out=open('debugLogs.txt', 'w'))
# Neo4j connection details
uri = "neo4j+s://c603e7b9-devtab1.databases.neo4j-dev.io"
username = "neo4j"             # Replace with your Neo4j username
password = "C-FtfcrRkFt2jbYavGm9SiZ4085IuhuLgh-UucNF_dc"          # Replace with your Neo4j password
class Neo4jDatabase:
    def __init__(self, uri, username, password):
        self.driver = GraphDatabase.driver(uri, auth=(username, password),liveness_check_timeout=180) # keep_alive=True, max_connection_lifetime=180)
    def close(self):
        self.driver.close()
    def query(self, cypher_query):
        with self.driver.session() as session:
            result = session.run(cypher_query)
            return [record.data() for record in result]
# Example usage
if __name__ == "__main__":
    neo4j_db = Neo4jDatabase(uri, username, password)
    for i in count(0):
        print('*' * 80)
        print(f"Connection {i}")
        print('*' * 80)
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
