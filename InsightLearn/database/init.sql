-- Initialize InsightLearn Database

CREATE DATABASE IF NOT EXISTS insightlearn;
USE insightlearn;

-- Create courses table
CREATE TABLE IF NOT EXISTS courses (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    instructor VARCHAR(100),
    duration INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create enrollments table
CREATE TABLE IF NOT EXISTS enrollments (
    id SERIAL PRIMARY KEY,
    student_name VARCHAR(100) NOT NULL,
    course_id INTEGER NOT NULL,
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    progress INTEGER DEFAULT 0,
    completed BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE
);

-- Create lessons table
CREATE TABLE IF NOT EXISTS lessons (
    id SERIAL PRIMARY KEY,
    course_id INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    video_url VARCHAR(500),
    order_index INTEGER NOT NULL,
    duration INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE
);

-- Create progress_tracking table
CREATE TABLE IF NOT EXISTS progress_tracking (
    id SERIAL PRIMARY KEY,
    enrollment_id INTEGER NOT NULL,
    lesson_id INTEGER NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP,
    FOREIGN KEY (enrollment_id) REFERENCES enrollments(id) ON DELETE CASCADE,
    FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
    UNIQUE(enrollment_id, lesson_id)
);

-- Insert sample data
INSERT INTO courses (title, description, instructor, duration) VALUES
('Introduction to Kubernetes', 'Learn the basics of container orchestration with Kubernetes', 'John Doe', 20),
('Python for Data Science', 'Master Python programming for data analysis and machine learning', 'Jane Smith', 30),
('Web Development with React', 'Build modern web applications using React and JavaScript', 'Mike Johnson', 25),
('Cloud Computing Fundamentals', 'Understand cloud architecture and services', 'Sarah Williams', 15),
('DevOps Best Practices', 'Learn CI/CD, automation, and infrastructure as code', 'Tom Brown', 35);

INSERT INTO lessons (course_id, title, content, order_index, duration) VALUES
(1, 'What is Kubernetes?', 'Introduction to container orchestration and Kubernetes concepts', 1, 2),
(1, 'Kubernetes Architecture', 'Understanding nodes, pods, and clusters', 2, 3),
(1, 'Deploying Your First App', 'Hands-on deployment tutorial', 3, 4),
(2, 'Python Basics', 'Variables, data types, and control structures', 1, 3),
(2, 'NumPy and Pandas', 'Working with data using popular libraries', 2, 5),
(3, 'React Components', 'Building reusable UI components', 1, 4),
(3, 'State Management', 'Managing application state with React hooks', 2, 3);

-- Create indexes for better performance
CREATE INDEX idx_enrollments_student ON enrollments(student_name);
CREATE INDEX idx_enrollments_course ON enrollments(course_id);
CREATE INDEX idx_lessons_course ON lessons(course_id);
CREATE INDEX idx_progress_enrollment ON progress_tracking(enrollment_id);