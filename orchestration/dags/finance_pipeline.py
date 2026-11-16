"""Triggers the Databricks finance-etl job deployed by the Databricks bundle."""
import os
from datetime import datetime

from airflow import DAG
from airflow.providers.databricks.operators.databricks import DatabricksRunNowOperator

ENV = os.environ.get("ENV_NAME", "dev")

with DAG(
    dag_id="databricks_pipeline",
    start_date=datetime(2025, 1, 1),
    schedule=None,  # enable a schedule once the Databricks deployment is verified
    catchup=False,
    tags=["databricks", "finance"],
) as dag:
    DatabricksRunNowOperator(
        task_id="run_finance_etl",
        databricks_conn_id="databricks_default",
        job_name=f"finance-etl-{ENV}",
    )
