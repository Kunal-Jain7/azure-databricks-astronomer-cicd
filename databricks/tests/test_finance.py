import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from finance_etl.main import get_args


def test_arguments():
    args = get_args(['--catalog', 'finance_dev', '--schema', 'silver'])
    assert args.catalog == 'finance_dev'
    assert args.schema == 'silver'
