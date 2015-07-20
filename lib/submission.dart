part of api;

// Submission API

/// Uploads a submission without authentication
@app.Route("/upload", methods: const [app.POST])
uploadSubmission(@Decode() Submission subm) async {
    cleanSubmissions();
    subm.time = new DateTime.now();
    String md5 = hash(subm);
    await db.execute("insert into uploads (md5, course, assignment, student, files, note) "
                     "values ('$md5', @course, @assignment, @student, @files, @note)", subm);
    return md5;
}

// Validates a submission (requires proper login)
@app.Route("/validate/:md5")
validateSubmission(String md5) async {
    cleanSubmissions();
    Submission subm = await findUpload(md5);
    if (subm == null) {
        return "No submission with hash $md5 exists";
    }
    await requireWrite(subm);
    Assignment assign = await assignmentInfo(subm.course, subm.assignment);
    if (assign == null) {
        return "No assignment '${subm.assignment}' exists in course '${subm.course}'";
    }
    subm.time = new DateTime.now();
    if (subm.time.isBefore(assign.open)) {
        return "This assignment is not yet open to submissions. Please try again after ${assign.open}";
    } else if (subm.time.isAfter(assign.close)) {
        return "This assignment is now closed to submissions as of ${assign.close}. Please contact your teacher if you need to submit.";
    }
    await db.execute("delete from submissions where course = @course and assignment = @assignment and student = @student", subm);
    await db.execute("insert into submissions (course, assignment, student, time, files, note) "
                    "values (@course, @assignment, @student, @time, @files, @note)", subm);
    await db.execute("delete from uploads where md5 = '$md5'");
    if (subm.time.isAfter(assign.deadline)) {
        return "Assignment submitted to course '${subm.course}' at ${subm.time}.\n"
                "Note that this is after the deadline of ${assign.deadline}";
    }
    return "Assignment successfully submitted to course '${subm.course}' at ${subm.time}";
}

// Finds an upload with the given MD5 hash
Submission findUpload(String md5) async {
    return first(db.query("select * from uploads where md5 = '$md5'", Submission));
}

// Removes uploads that are older than 10 minutes
// Should eventually remove submissions after some time?
cleanSubmissions([database = null]) async {
    if (database == null) database = db;
    await database.execute("delete from uploads where time < now() - interval '10 minutes'");
}