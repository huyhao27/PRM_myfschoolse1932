using System;
using System.Configuration;
using MongoDB.Driver;
using MyfschoolWeb.Models;

namespace MyfschoolWeb.DataAccess
{
    public class MongoDbContext
    {
        private static readonly Lazy<MongoDbContext> _instance = 
            new Lazy<MongoDbContext>(() => new MongoDbContext());

        public static MongoDbContext Instance => _instance.Value;

        private readonly IMongoDatabase _database;

        private MongoDbContext()
        {
            string connectionString = ConfigurationManager.ConnectionStrings["MongoConnection"]?.ConnectionString 
                                      ?? "mongodb://127.0.0.1:27017";
            string databaseName = ConfigurationManager.ConnectionStrings["MongoDatabase"]?.ConnectionString 
                                  ?? "myfschool_db";

            var client = new MongoClient(connectionString);
            _database = client.GetDatabase(databaseName);
        }

        public IMongoCollection<UserModel> Users => _database.GetCollection<UserModel>("users");
        public IMongoCollection<GradeModel> Grades => _database.GetCollection<GradeModel>("grades");
        public IMongoCollection<ScheduleModel> Schedules => _database.GetCollection<ScheduleModel>("schedules");

        public bool TestConnection(out string error)
        {
            try
            {
                var collections = _database.ListCollectionNames().ToList();
                error = null;
                return true;
            }
            catch (Exception ex)
            {
                error = ex.Message;
                return false;
            }
        }
    }
}
