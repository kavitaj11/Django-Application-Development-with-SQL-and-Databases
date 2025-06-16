import os
from datetime import date

# Django settings setup
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "settings")
from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()

from crud.models import User, Instructor, Learner, Course, Lesson, Enrollment

def clean_data():
    # Delete all data to start fresh
    Enrollment.objects.all().delete()
    Lesson.objects.all().delete()
    Course.objects.all().delete()
    Instructor.objects.all().delete()
    Learner.objects.all().delete()
    User.objects.all().delete()
    print("All data cleaned...")

def write_instructors():
    instructor_yan = Instructor(first_name='Yan', last_name='Luo', dob=date(1962, 7, 16), full_time=True, total_learners=30050)
    instructor_yan.save()

    instructor_joy = Instructor(first_name='Joy', last_name='Li', dob=date(1992, 1, 2), full_time=False, total_learners=10040)
    instructor_joy.save()

    instructor_peter = Instructor(first_name='Peter', last_name='Chen', dob=date(1982, 5, 2), full_time=True, total_learners=2002)
    instructor_peter.save()

    print("Instructor objects all saved...")

def write_courses():
    course1 = Course(name="Cloud Application Development with Database",
                     description="Develop and deploy application on cloud")
    course1.save()

    course2 = Course(name="Introduction to Python",
                     description="Learn core concepts of Python and obtain hands-on experience via a capstone project")
    course2.save()

    print("Course objects all saved...")

def write_learners():
    learner1 = Learner(
        first_name="Alice",
        last_name="Brown",
        dob=date(1990, 3, 15),
        occupation=Learner.STUDENT,
        social_link="http://example.com/alice"
    )
    learner1.save()

    learner2 = Learner(
        first_name="Bob",
        last_name="Smith",
        dob=date(1988, 8, 22),
        occupation=Learner.DEVELOPER,
        social_link="http://example.com/bob"
    )
    learner2.save()

    learner3 = Learner(
        first_name="Cara",
        last_name="Davis",
        dob=date(1995, 12, 5),
        occupation=Learner.DATA_SCIENTIST,
        social_link="http://example.com/cara"
    )
    learner3.save()

    print("Learner objects all saved...")

def write_enrollments():
    learner1 = Learner.objects.get(first_name="Alice", last_name="Brown")
    learner2 = Learner.objects.get(first_name="Bob", last_name="Smith")
    learner3 = Learner.objects.get(first_name="Cara", last_name="Davis")

    course1 = Course.objects.get(name="Cloud Application Development with Database")
    course2 = Course.objects.get(name="Introduction to Python")

    Enrollment.objects.create(learner=learner1, course=course1, mode=Enrollment.AUDIT)
    Enrollment.objects.create(learner=learner2, course=course1, mode=Enrollment.HONOR)
    Enrollment.objects.create(learner=learner2, course=course2, mode=Enrollment.AUDIT)
    Enrollment.objects.create(learner=learner3, course=course2, mode=Enrollment.HONOR)

    print("Enrollment objects all saved...")

def write_lessons():
    course1 = Course.objects.get(name="Cloud Application Development with Database")
    course2 = Course.objects.get(name="Introduction to Python")

    Lesson.objects.create(title='Lesson 1 - ORM Basics', content="Object-relational mapping in Django", course=course1)
    Lesson.objects.create(title='Lesson 2 - Models and Migrations', content="Creating and updating models", course=course1)

    Lesson.objects.create(title='Lesson 1 - Python Syntax', content="Learn the basics of Python syntax and data types", course=course2)
    Lesson.objects.create(title='Lesson 2 - Functions and Loops', content="Work with loops, functions, and logic in Python", course=course2)

    print("Lesson objects all saved...")

# Execute functions in order
clean_data()
write_courses()
write_instructors()
write_learners()
write_enrollments()
write_lessons()
