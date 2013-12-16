package action

import (
	boshsys "bosh/system"
	boshas "bosh/agent/applier/applyspec"
	boshsettings "bosh/settings"
	bosherr "bosh/errors"
	"path/filepath"
	"encoding/json"
)


type drainAction struct{
	cmdRunner boshsys.CmdRunner
	fs boshsys.FileSystem
}

func newDrain(cmdRunner boshsys.CmdRunner, fs boshsys.FileSystem) (drain drainAction) {
	drain.cmdRunner = cmdRunner
	drain.fs = fs
	return
}

func (a drainAction) IsAsynchronous() bool {
	return true
}

func (a drainAction) Run(drainType string, newSpec boshas.V1ApplySpec) (value interface{}, err error) {
	oldSpec, err := a.getCurrentSpec()
	if err != nil {
	    return
	}

	newSpecJson, err := marshalSpec(newSpec)
	if err != nil {
		err = bosherr.WrapError(err, "Marshaling new spec")
	    return
	}

	oldSpecJson, err := marshalSpec(oldSpec)
	if err != nil {
		err = bosherr.WrapError(err, "Marshaling old spec")
	    return
	}

	command := boshsys.Command{
		Name: filepath.Join(boshsettings.VCAP_JOBS_DIR, oldSpec.JobSpec.Template, "bin", "drain"),
		Args: []string{"job_shutdown", "hash_unchanged"},
		Env: map[string]string{
			"PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
			"BOSH_CURRENT_STATE": newSpecJson,
			"BOSH_APPLY_SPEC": oldSpecJson,
		},
	}
	a.cmdRunner.RunComplexCommand(command)

	value = 0
	return
}

func (a drainAction) getCurrentSpec() (currentSpec boshas.V1ApplySpec, err error) {
	contents, err := a.fs.ReadFile(filepath.Join(boshsettings.VCAP_BASE_DIR, "bosh", "spec.json"))
	if err != nil {
		err = bosherr.WrapError(err, "Reading json spec file")
		return
	}

	err = json.Unmarshal([]byte(contents), &currentSpec)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling json spec file")
		return
	}

	return
}


func marshalSpec(spec boshas.V1ApplySpec) (contents string, err error) {
	bytes, err := json.Marshal(spec)
	if err != nil {
	    return
	}
	contents = string(bytes)
	return
}
