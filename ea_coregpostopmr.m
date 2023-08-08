function done = ea_coregpostopmr(options)
% Entry function to coregister post-op MRI to pre-op MRI

done = 0;

% Set fixed anchor image
anchor = options.subj.preopAnat.(options.subj.AnchorModality).coreg;

% Post-op MR modalities
postopModality = fieldnames(options.subj.postopAnat);

% Set moving and output image
moving = cellfun(@(x) options.subj.postopAnat.(x).preproc, postopModality, 'Uni', 0);
output = cellfun(@(x) options.subj.postopAnat.(x).coreg, postopModality, 'Uni', 0);

% Check moving image existence
moving_exists = cellfun(@(x) isfile(x), moving);

% Check registration lock/approval status
output_approved = cellfun(@(x) logical(ea_reglocked(options, x)), output);

% Remove non-existing moving image and approved output image
moving(~moving_exists | output_approved) = [];
output(~moving_exists | output_approved) = [];

% Return if no image remains
if isempty(moving)
    return;
end

% Setup log
if options.prefs.diary
    ea_mkdir(fileparts(options.subj.coreg.log.logBaseName));
    diary([options.subj.coreg.log.logBaseName, 'MR', datestr(now, 'yyyymmddTHHMMss'), '.log']);
end

if strcmp(options.coregmr.method, 'ANTs Nonlinear Coregistration')
    warning('off', 'backtrace');
    warndlg(sprintf('ANTs nonlinear coregistration only supports pre-op to pre-op!\nFalling back to ANTs linear coregistration for post-op to pre-op now.'))
    warning('on', 'backtrace');
    options.coregmr.method = 'ANTs';
end

% Do coregistration
for i=1:length(moving)
    ea_dumpmethod(options, 'coreg', ea_getmodality(moving{i}));
    affinefile = ea_coregimages(options, moving{i}, anchor, output{i}, [], 1);
    %% save Transforms
    switch lower(options.coregmr.method)
        case lower({'ANTs (Avants 2008)', 'ANTs'})
            movefile(affinefile{1},[options.subj.coreg.transform.postop_space.forwardBaseName, 'ants.mat']);
            movefile(affinefile{2},[options.subj.coreg.transform.postop_space.inverseBaseName, 'ants.mat']);
            % convert ANTS matrices to 4x4
            load([options.subj.coreg.transform.postop_space.forwardBaseName, 'ants.mat'])
            tmat = ea_antsmat2mat(AffineTransform_float_3_3,fixed);
            save([options.subj.coreg.transform.postop_space.inverseBaseName, 'ants_4x4.mat'],'tmat')
            load([options.subj.coreg.transform.postop_space.forwardBaseName, 'ants.mat'])
            tmat = ea_antsmat2mat(AffineTransform_float_3_3,fixed);
            save([options.subj.coreg.transform.postop_space.inverseBaseName, 'ants_4x4.mat'],'tmat')
        case lower({'FLIRT (Jenkinson 2001 & 2002)', 'FLIRT'})
            movefile(affinefile{1},[options.subj.coreg.transform.postop_space.forwardBaseName, 'flirt.mat']);
            movefile(affinefile{2},[options.subj.coreg.transform.postop_space.inverseBaseName, 'flirt.mat']);
            % convert affinefile from txt to tmat
            tmat = readmatrix([options.subj.coreg.transform.postop_space.forwardBaseName, 'flirt.mat'],'FileType','text');
            save([options.subj.coreg.transform.postop_space.forwardBaseName, 'flirt_4x4.mat'],'tmat');
            tmat = readmatrix([options.subj.coreg.transform.postop_space.inverseBaseName, 'flirt.mat'],'FileType','text');
            save([options.subj.coreg.transform.postop_space.inverseBaseName, 'flirt_4x4.mat'],'tmat');
        case lower({'SPM (Friston 2007)', 'SPM'})
            movefile(affinefile{1},[options.subj.coreg.transform.postop_space.forwardBaseName, 'spm.mat']);
            movefile(affinefile{2},[options.subj.coreg.transform.postop_space.inverseBaseName, 'spm.mat']);
            % also store tmat separatly analogous to the the other methods
            load([options.subj.coreg.transform.postop_space.forwardBaseName, 'spm.mat'],'tmat')
            save([options.subj.coreg.transform.postop_space.forwardBaseName, 'spm_4x4.mat'],'tmat')
            load([options.subj.coreg.transform.postop_space.inverseBaseName, 'spm.mat'],'tmat')
            save([options.subj.coreg.transform.postop_space.inverseBaseName, 'spm_4x4.mat'],'tmat')
    end
end

if options.prefs.diary
    diary off;
end

done = 1;
