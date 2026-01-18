from django.urls import path

from students.views import StudentListCreateView, StudentDetailView, StudentDetailWithPapersView, StudentImportView, StudentExportCSVView, StudentExportExcelView

urlpatterns = [
    path('', StudentListCreateView.as_view(), name='student-list-create'),
    path('import/', StudentImportView.as_view(), name='student-import'),
    path('export/csv/', StudentExportCSVView.as_view(), name='student-export-csv'),
    path('export/excel/', StudentExportExcelView.as_view(), name='student-export-excel'),
    path('<str:student_id>/detail/', StudentDetailWithPapersView.as_view(), name='student-detail-with-papers'),
    path('<str:student_id>/', StudentDetailView.as_view(), name='student-detail'),
]