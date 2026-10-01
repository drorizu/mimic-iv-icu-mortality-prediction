# Local Setup

To build the MIMIC-IV Demo PostgreSQL database locally:

## 1. Install PostgreSQL

Download and install PostgreSQL
 for your operating system. Complete the initial setup, including setting a PostgreSQL password.

## 2. Clone this repository
git clone <repository-url>

## 3. Download the MIMIC-IV Demo

Download the MIMIC-IV Clinical Database Demo
 and unarchive the downloaded file.

## 4. Place the folders side by side

Save the extracted MIMIC-IV Demo folder in the same parent directory as the cloned repository:
```
my-projects/
├── mimic-iv-demo/
│   ├── hosp/
│   └── icu/
│
└── your-repository/
    └── postgres_init/
        └── buildmimic.sh
```
## 5. Open the postgres_init directory

From your CLI, navigate to the postgres_init directory:

cd path/to/your-repository/postgres_init

## 6. Connect to PostgreSQL
psql


Enter your PostgreSQL password when prompted.

## 7. Build the database

Run:

```bash
./buildmimic.sh
```

The script creates the PostgreSQL schema, tables, constraints, and indexes, and loads the MIMIC-IV Demo data into PostgreSQL.

