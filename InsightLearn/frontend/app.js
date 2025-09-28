const API_URL = window.location.hostname === 'localhost'
    ? 'http://localhost:5000'
    : '';

let selectedCourseId = null;

async function loadCourses() {
    try {
        const response = await fetch(`${API_URL}/api/courses`);
        const courses = await response.json();
        displayCourses(courses);
    } catch (error) {
        console.error('Error loading courses:', error);
        document.getElementById('course-list').innerHTML = '<p>Error loading courses. Please try again later.</p>';
    }
}

function displayCourses(courses) {
    const courseList = document.getElementById('course-list');

    if (courses.length === 0) {
        courseList.innerHTML = '<p>No courses available yet. Add your first course!</p>';
        return;
    }

    courseList.innerHTML = courses.map(course => `
        <div class="course-card">
            <h3>${course.title}</h3>
            <p>${course.description || 'No description available'}</p>
            <div class="course-meta">
                <span>Instructor: ${course.instructor || 'TBA'}</span>
                <span>${course.duration ? course.duration + ' hours' : ''}</span>
            </div>
            <button class="enroll-btn" onclick="openEnrollModal(${course.id})">Enroll</button>
        </div>
    `).join('');
}

document.getElementById('course-form').addEventListener('submit', async (e) => {
    e.preventDefault();

    const courseData = {
        title: document.getElementById('title').value,
        description: document.getElementById('description').value,
        instructor: document.getElementById('instructor').value,
        duration: parseInt(document.getElementById('duration').value) || null
    };

    try {
        const response = await fetch(`${API_URL}/api/courses`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(courseData)
        });

        if (response.ok) {
            alert('Course added successfully!');
            document.getElementById('course-form').reset();
            loadCourses();
        } else {
            alert('Error adding course. Please try again.');
        }
    } catch (error) {
        console.error('Error adding course:', error);
        alert('Error adding course. Please try again.');
    }
});

function openEnrollModal(courseId) {
    selectedCourseId = courseId;
    document.getElementById('enrollment-modal').style.display = 'block';
}

async function enrollStudent() {
    const studentName = document.getElementById('student-name').value;

    if (!studentName) {
        alert('Please enter your name');
        return;
    }

    try {
        const response = await fetch(`${API_URL}/api/enrollments`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                student_name: studentName,
                course_id: selectedCourseId
            })
        });

        if (response.ok) {
            alert('Enrollment successful!');
            closeModal();
            document.getElementById('student-name').value = '';
        } else {
            alert('Error enrolling. Please try again.');
        }
    } catch (error) {
        console.error('Error enrolling:', error);
        alert('Error enrolling. Please try again.');
    }
}

function closeModal() {
    document.getElementById('enrollment-modal').style.display = 'none';
    selectedCourseId = null;
}

document.querySelector('.close').addEventListener('click', closeModal);

window.addEventListener('click', (event) => {
    const modal = document.getElementById('enrollment-modal');
    if (event.target === modal) {
        closeModal();
    }
});

window.addEventListener('load', loadCourses);