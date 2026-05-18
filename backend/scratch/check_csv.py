import httpx
import pandas as pd
from io import StringIO

URL = "https://docs.google.com/spreadsheets/d/e/2PACX-1vT8xPlBR5CsIpJHN6JnMBqSkyPpZfdmINuPPo8Pq7NS7L0i-HnC3RAtGrszUU-6BM6eC9Hhq8lhCk9z/pub?gid=0&single=true&output=csv"

def check():
    r = httpx.get(URL, follow_redirects=True)
    df = pd.read_csv(StringIO(r.text))
    print("Original Columns:", df.columns.tolist())
    print("First 2 rows:")
    print(df.head(2).to_dict(orient="records"))

if __name__ == "__main__":
    check()
