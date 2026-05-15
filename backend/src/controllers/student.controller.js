const studentService = require('../services/student.service');

async function getProfile(req, res, next) {
  try {
    const student = await studentService.getStudentProfile(req.user.sub);
    res.json({ student });
  } catch (err) {
    next(err);
  }
}

async function updateProfile(req, res, next) {
  try {
    const student = await studentService.updateStudentProfile(req.user.sub, req.body);
    res.json({ student });
  } catch (err) {
    next(err);
  }
}

async function updatePhoto(req, res, next) {
  try {
    const student = await studentService.updateStudentPhoto(req.user.sub, req.file);
    res.json({ student });
  } catch (err) {
    next(err);
  }
}

async function listStudents(req, res, next) {
  try {
    const result = await studentService.listAllStudents(req.query, req.user.sub);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

async function getStudentById(req, res, next) {
  try {
    const student = await studentService.getStudentById(Number(req.params.id), req.user.sub);
    res.json({ student });
  } catch (err) {
    next(err);
  }
}

async function adminCreateStudent(req, res, next) {
  try {
    const student = await studentService.adminCreateStudent(req.body, req.user.sub);
    res.status(201).json({ student });
  } catch (err) {
    next(err);
  }
}

async function adminUpdateStudent(req, res, next) {
  try {
    const student = await studentService.adminUpdateStudent(
      Number(req.params.id),
      req.body,
      req.user.sub
    );
    res.json({ student });
  } catch (err) {
    next(err);
  }
}

async function adminUpdateStudentPhoto(req, res, next) {
  try {
    const student = await studentService.adminUpdateStudentPhoto(Number(req.params.id), req.file, req.user.sub);
    res.json({ student });
  } catch (err) {
    next(err);
  }
}

async function adminDeleteStudent(req, res, next) {
  try {
    await studentService.adminDeleteStudent(Number(req.params.id), req.user.sub);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getProfile,
  updateProfile,
  updatePhoto,
  listStudents,
  getStudentById,
  adminCreateStudent,
  adminUpdateStudent,
  adminUpdateStudentPhoto,
  adminDeleteStudent
};
