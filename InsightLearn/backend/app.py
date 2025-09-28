from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
import os
from datetime import datetime

app = Flask(__name__)
CORS(app)

app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'postgresql://user:password@localhost/insightlearn')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

class Course(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text)
    instructor = db.Column(db.String(100))
    duration = db.Column(db.Integer)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Enrollment(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    student_name = db.Column(db.String(100), nullable=False)
    course_id = db.Column(db.Integer, db.ForeignKey('course.id'), nullable=False)
    enrolled_at = db.Column(db.DateTime, default=datetime.utcnow)
    progress = db.Column(db.Integer, default=0)

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "InsightLearn API"})

@app.route('/api/courses', methods=['GET'])
def get_courses():
    courses = Course.query.all()
    return jsonify([{
        'id': c.id,
        'title': c.title,
        'description': c.description,
        'instructor': c.instructor,
        'duration': c.duration
    } for c in courses])

@app.route('/api/courses', methods=['POST'])
def create_course():
    data = request.json
    course = Course(
        title=data['title'],
        description=data.get('description'),
        instructor=data.get('instructor'),
        duration=data.get('duration')
    )
    db.session.add(course)
    db.session.commit()
    return jsonify({'id': course.id, 'message': 'Course created successfully'}), 201

@app.route('/api/enrollments', methods=['POST'])
def enroll():
    data = request.json
    enrollment = Enrollment(
        student_name=data['student_name'],
        course_id=data['course_id']
    )
    db.session.add(enrollment)
    db.session.commit()
    return jsonify({'message': 'Enrollment successful'}), 201

@app.route('/api/enrollments/<int:course_id>')
def get_enrollments(course_id):
    enrollments = Enrollment.query.filter_by(course_id=course_id).all()
    return jsonify([{
        'id': e.id,
        'student_name': e.student_name,
        'progress': e.progress,
        'enrolled_at': e.enrolled_at.isoformat()
    } for e in enrollments])

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=5000, debug=True)