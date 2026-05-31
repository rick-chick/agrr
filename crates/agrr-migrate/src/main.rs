use agrr_migrate::config::DbPaths;
use agrr_migrate::{data, schema, stamp};
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "agrr-migrate", about = "AGRR schema (refinery) and reference data CLI")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Schema migrations (refinery; runs on startup in production)
    Schema {
        #[command(subcommand)]
        cmd: SchemaCommand,
    },
    /// Reference data migrations (manual; not run on startup)
    Data {
        #[command(subcommand)]
        cmd: DataCommand,
    },
}

#[derive(Subcommand)]
enum SchemaCommand {
    /// Apply pending schema migrations (primary + cache)
    Run,
    /// Show schema migration status
    Status,
    /// Verify required tables and refinery version
    Verify,
    /// Stamp legacy Rails schema as applied (existing Litestream DBs)
    Stamp {
        #[arg(long)]
        dry_run: bool,
    },
}

#[derive(Subcommand)]
enum DataCommand {
    /// List data migration status
    List,
    /// Apply reference data migrations for regions and kinds
    Apply {
        #[arg(long, default_value = "jp,in,us")]
        region: String,
        /// Comma-separated kinds (e.g. `base,nutrients,pests,tasks,templates`)
        #[arg(long, default_value = "base,nutrients,pests,tasks")]
        kind: String,
    },
    /// Stamp legacy data migrations as applied without running
    Stamp {
        #[arg(long)]
        dry_run: bool,
    },
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    let paths = DbPaths::from_env()?;

    match cli.command {
        Command::Schema { cmd } => match cmd {
            SchemaCommand::Run => schema::run(&paths)?,
            SchemaCommand::Status => schema::status(&paths)?,
            SchemaCommand::Verify => schema::verify(&paths)?,
            SchemaCommand::Stamp { dry_run } => {
                stamp::stamp_schema_legacy(&paths, dry_run)?;
            }
        },
        Command::Data { cmd } => match cmd {
            DataCommand::List => data::list(&paths)?,
            DataCommand::Apply { region, kind } => data::apply(&paths, &region, &kind)?,
            DataCommand::Stamp { dry_run } => stamp::stamp_data_legacy(&paths, dry_run)?,
        },
    }
    Ok(())
}
