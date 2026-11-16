from pathlib import Path

from airflow.models import DagBag

DAGS = Path(__file__).resolve().parents[1] / "dags"


def test_no_import_errors():
    bag = DagBag(dag_folder=str(DAGS), include_examples=False)
    assert bag.import_errors == {}


def test_pipeline_dag_present():
    bag = DagBag(dag_folder=str(DAGS), include_examples=False)
    dag = bag.dags.get("databricks_pipeline")
    assert dag is not None
    assert [t.task_id for t in dag.tasks] == ["run_finance_etl"]
