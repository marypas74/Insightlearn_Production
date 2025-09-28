using Microsoft.EntityFrameworkCore;
using InsightLearn.Core.Models;

namespace InsightLearn.Infrastructure.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options)
    {
    }

    // User and Authentication tables
    public DbSet<User> Users { get; set; }
    public DbSet<Role> Roles { get; set; }
    public DbSet<UserRole> UserRoles { get; set; }
    public DbSet<Permission> Permissions { get; set; }
    public DbSet<RolePermission> RolePermissions { get; set; }
    public DbSet<RefreshToken> RefreshTokens { get; set; }
    public DbSet<OAuthProvider> OAuthProviders { get; set; }
    public DbSet<AuditLog> AuditLogs { get; set; }

    // Video system tables
    public DbSet<Video> Videos { get; set; }
    public DbSet<VideoMetadata> VideoMetadata { get; set; }
    public DbSet<VideoProcessingJob> VideoProcessingJobs { get; set; }
    public DbSet<VideoThumbnail> VideoThumbnails { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User Configuration
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Email).IsUnique();
            entity.Property(e => e.Email).IsRequired().HasMaxLength(255);
            entity.Property(e => e.FirstName).IsRequired().HasMaxLength(100);
            entity.Property(e => e.LastName).IsRequired().HasMaxLength(100);
            entity.Property(e => e.PasswordHash).IsRequired();
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
        });

        // Role Configuration
        modelBuilder.Entity<Role>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Name).IsUnique();
            entity.Property(e => e.Name).IsRequired().HasMaxLength(50);
            entity.Property(e => e.Description).HasMaxLength(255);
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
        });

        // UserRole Configuration (Many-to-Many)
        modelBuilder.Entity<UserRole>(entity =>
        {
            entity.HasKey(e => new { e.UserId, e.RoleId });
            entity.HasOne(e => e.User)
                  .WithMany(e => e.UserRoles)
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.Role)
                  .WithMany(e => e.UserRoles)
                  .HasForeignKey(e => e.RoleId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.Property(e => e.AssignedAt).HasDefaultValueSql("GETUTCDATE()");
        });

        // Permission Configuration
        modelBuilder.Entity<Permission>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Name).IsUnique();
            entity.Property(e => e.Name).IsRequired().HasMaxLength(100);
            entity.Property(e => e.Description).HasMaxLength(255);
            entity.Property(e => e.Category).HasMaxLength(50);
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
        });

        // RolePermission Configuration (Many-to-Many)
        modelBuilder.Entity<RolePermission>(entity =>
        {
            entity.HasKey(e => new { e.RoleId, e.PermissionId });
            entity.HasOne(e => e.Role)
                  .WithMany(e => e.RolePermissions)
                  .HasForeignKey(e => e.RoleId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.Permission)
                  .WithMany(e => e.RolePermissions)
                  .HasForeignKey(e => e.PermissionId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.Property(e => e.GrantedAt).HasDefaultValueSql("GETUTCDATE()");
        });

        // RefreshToken Configuration
        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Token).IsUnique();
            entity.Property(e => e.Token).IsRequired();
            entity.HasOne(e => e.User)
                  .WithMany(e => e.RefreshTokens)
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
        });

        // OAuthProvider Configuration
        modelBuilder.Entity<OAuthProvider>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.Provider, e.ProviderUserId }).IsUnique();
            entity.Property(e => e.Provider).IsRequired().HasMaxLength(50);
            entity.Property(e => e.ProviderUserId).IsRequired();
            entity.HasOne(e => e.User)
                  .WithMany(e => e.OAuthProviders)
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.Property(e => e.ConnectedAt).HasDefaultValueSql("GETUTCDATE()");
        });

        // AuditLog Configuration
        modelBuilder.Entity<AuditLog>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Action).IsRequired().HasMaxLength(100);
            entity.Property(e => e.Entity).HasMaxLength(100);
            entity.HasOne(e => e.User)
                  .WithMany(e => e.AuditLogs)
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.SetNull);
            entity.Property(e => e.Timestamp).HasDefaultValueSql("GETUTCDATE()");
        });

        // Video Configuration
        modelBuilder.Entity<Video>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Title).IsRequired().HasMaxLength(200);
            entity.Property(e => e.Description).HasMaxLength(1000);
            entity.Property(e => e.FileName).IsRequired();
            entity.Property(e => e.FilePath).IsRequired();
            entity.Property(e => e.VideoFormat).HasMaxLength(50);
            entity.Property(e => e.UploadedAt).HasDefaultValueSql("GETUTCDATE()");
        });

        // VideoMetadata Configuration
        modelBuilder.Entity<VideoMetadata>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Key).IsRequired();
            entity.HasOne(e => e.Video)
                  .WithMany(e => e.Metadata)
                  .HasForeignKey(e => e.VideoId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // VideoProcessingJob Configuration
        modelBuilder.Entity<VideoProcessingJob>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasOne(e => e.Video)
                  .WithMany()
                  .HasForeignKey(e => e.VideoId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.Property(e => e.StartedAt).HasDefaultValueSql("GETUTCDATE()");
        });

        // VideoThumbnail Configuration
        modelBuilder.Entity<VideoThumbnail>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.FilePath).IsRequired();
            entity.HasOne(e => e.Video)
                  .WithMany()
                  .HasForeignKey(e => e.VideoId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // Seed Default Data
        SeedDefaultData(modelBuilder);
    }

    private void SeedDefaultData(ModelBuilder modelBuilder)
    {
        // Seed Default Roles
        modelBuilder.Entity<Role>().HasData(
            new Role { Id = 1, Name = "Student", Description = "Default student role", IsDefault = true },
            new Role { Id = 2, Name = "Instructor", Description = "Instructor role for content creators" },
            new Role { Id = 3, Name = "Admin", Description = "Administrator role with full access" }
        );

        // Seed Default Permissions
        var permissions = new List<Permission>
        {
            // User permissions
            new Permission { Id = 1, Name = "user.view", Description = "View user profile", Category = "User" },
            new Permission { Id = 2, Name = "user.edit", Description = "Edit user profile", Category = "User" },
            new Permission { Id = 3, Name = "user.delete", Description = "Delete user account", Category = "User" },

            // Course permissions
            new Permission { Id = 4, Name = "course.view", Description = "View courses", Category = "Course" },
            new Permission { Id = 5, Name = "course.create", Description = "Create new courses", Category = "Course" },
            new Permission { Id = 6, Name = "course.edit", Description = "Edit courses", Category = "Course" },
            new Permission { Id = 7, Name = "course.delete", Description = "Delete courses", Category = "Course" },
            new Permission { Id = 8, Name = "course.enroll", Description = "Enroll in courses", Category = "Course" },

            // Video permissions
            new Permission { Id = 9, Name = "video.view", Description = "View videos", Category = "Video" },
            new Permission { Id = 10, Name = "video.upload", Description = "Upload videos", Category = "Video" },
            new Permission { Id = 11, Name = "video.edit", Description = "Edit video details", Category = "Video" },
            new Permission { Id = 12, Name = "video.delete", Description = "Delete videos", Category = "Video" },

            // Admin permissions
            new Permission { Id = 13, Name = "admin.users", Description = "Manage users", Category = "Admin" },
            new Permission { Id = 14, Name = "admin.roles", Description = "Manage roles and permissions", Category = "Admin" },
            new Permission { Id = 15, Name = "admin.system", Description = "System administration", Category = "Admin" },
        };

        modelBuilder.Entity<Permission>().HasData(permissions);

        // Seed Role Permissions
        var rolePermissions = new List<RolePermission>
        {
            // Student permissions
            new RolePermission { RoleId = 1, PermissionId = 1, GrantedBy = 1 }, // user.view
            new RolePermission { RoleId = 1, PermissionId = 2, GrantedBy = 1 }, // user.edit
            new RolePermission { RoleId = 1, PermissionId = 4, GrantedBy = 1 }, // course.view
            new RolePermission { RoleId = 1, PermissionId = 8, GrantedBy = 1 }, // course.enroll
            new RolePermission { RoleId = 1, PermissionId = 9, GrantedBy = 1 }, // video.view

            // Instructor permissions (includes all student permissions plus content creation)
            new RolePermission { RoleId = 2, PermissionId = 1, GrantedBy = 1 }, // user.view
            new RolePermission { RoleId = 2, PermissionId = 2, GrantedBy = 1 }, // user.edit
            new RolePermission { RoleId = 2, PermissionId = 4, GrantedBy = 1 }, // course.view
            new RolePermission { RoleId = 2, PermissionId = 5, GrantedBy = 1 }, // course.create
            new RolePermission { RoleId = 2, PermissionId = 6, GrantedBy = 1 }, // course.edit
            new RolePermission { RoleId = 2, PermissionId = 8, GrantedBy = 1 }, // course.enroll
            new RolePermission { RoleId = 2, PermissionId = 9, GrantedBy = 1 }, // video.view
            new RolePermission { RoleId = 2, PermissionId = 10, GrantedBy = 1 }, // video.upload
            new RolePermission { RoleId = 2, PermissionId = 11, GrantedBy = 1 }, // video.edit

            // Admin permissions (all permissions)
            new RolePermission { RoleId = 3, PermissionId = 1, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 2, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 3, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 4, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 5, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 6, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 7, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 8, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 9, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 10, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 11, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 12, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 13, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 14, GrantedBy = 1 },
            new RolePermission { RoleId = 3, PermissionId = 15, GrantedBy = 1 },
        };

        modelBuilder.Entity<RolePermission>().HasData(rolePermissions);
    }
}