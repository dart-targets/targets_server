part of api;

// Submission API

/// Uploads a submission without authentication
@app.Route("/upload", methods: const [app.POST])
uploadSubmission(@Decode() Submission subm) async {
    cleanSubmissions();
    subm.time = new DateTime.now().millisecondsSinceEpoch;
    String md5 = hash(subm);
    await db.execute("insert into uploads (md5, course, assignment, student, files, note, time) "
                     "values ('$md5', @course, @assignment, @student, @files, @note, @time)", subm);
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
    subm.time = new DateTime.now().millisecondsSinceEpoch;
    if (subm.time < assign.open) {
        return "This assignment is not yet open to submissions. Please try again after ${assign.open}";
    } else if (subm.time > assign.close) {
        return "This assignment is now closed to submissions as of ${assign.close}. Please contact your teacher if you need to submit.";
    }
    await db.execute("delete from submissions where course = @course and assignment = @assignment and student = @student", subm);
    await db.execute("insert into submissions (course, assignment, student, time, files, note) "
                    "values (@course, @assignment, @student, @time, @files, @note)", subm);
    await db.execute("delete from uploads where md5 = '$md5'");
    if (subm.time >= assign.deadline) {
        return "Assignment submitted to course '${subm.course}' at ${subm.time}. "
                "Note that this is after the deadline of ${assign.deadline}";
    }
    return "Assignment successfully submitted to course '${subm.course}' at ${subm.time}";
}


// Finds an upload with the given MD5 hash
@app.Route("/upload/:md5")
@Encode()
findUpload(String md5) async {
    return requireWrite(first(db.query("select * from uploads where md5 = '$md5'", Submission)));
}

// Removes uploads that are older than 10 minutes
// Should eventually remove submissions after some time?
cleanSubmissions([database = null]) async {
    if (database == null) database = db;
    int boundary = new DateTime.now().millisecondsSinceEpoch - 10*60*1000;
    await database.execute("delete from uploads where time < $boundary");
}